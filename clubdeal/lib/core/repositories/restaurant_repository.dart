import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/menu_item.dart';
import '../models/order_model.dart';
import '../models/stock_movement_model.dart';
class RestaurantRepository {
 final FirebaseFirestore _firestore;
 RestaurantRepository({FirebaseFirestore? firestore}):_firestore=firestore??FirebaseFirestore.instance;
 CollectionReference<Map<String,dynamic>> get _orders=>_firestore.collection('orders');
 CollectionReference<Map<String,dynamic>> get _menu=>_firestore.collection('menu2');
 Stream<List<RestaurantOrder>> watchOrders()=>_orders.snapshots().map((s)=>s.docs.map(RestaurantOrder.fromDocument).toList()..sort((a,b)=>(b.createdAt??DateTime(1970)).compareTo(a.createdAt??DateTime(1970))));
 Stream<List<MenuItemModel>> watchMenu()=>_menu.snapshots().map((s)=>s.docs.map(MenuItemModel.fromDocument).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase())));
 Future<void> updateOrderStatus(String id,OrderStatus status)async{final m=<String,dynamic>{'status':status.name,'updatedAt':FieldValue.serverTimestamp()};if(status==OrderStatus.delivered)m['deliveredAt']=FieldValue.serverTimestamp();if(status==OrderStatus.cancelled)m['cancelledAt']=FieldValue.serverTimestamp();await _orders.doc(id).update(m);}
 Future<void> reserveOrderInventory(String orderId) async {
  final orderRef = _orders.doc(orderId);
  final snapshot = await orderRef.get();
  if (!snapshot.exists) return;
  final order = RestaurantOrder.fromDocument(snapshot);
  if (order.status == OrderStatus.cancelled || order.status == OrderStatus.delivered) return;
  final usage = <String, double>{};
  for (final item in order.items) {
    final matches = await _menu.where('name', isEqualTo: item.name).limit(1).get();
    if (matches.docs.isEmpty) continue;
    final data = matches.docs.first.data();
    final lines = data['recipeLines'];
    if (lines is List && lines.isNotEmpty) {
      for (final raw in lines.whereType<Map>()) {
        final line = Map<String, dynamic>.from(raw);
        final id = (line['ingredientId'] ?? '').toString();
        final quantity = (line['quantity'] as num?)?.toDouble() ?? 0;
        if (id.isNotEmpty && quantity > 0) usage[id] = (usage[id] ?? 0) + quantity * item.qty;
      }
    } else {
      final legacy = data['ingredientUsage'];
      if (legacy is Map) {
        final m = Map<String, dynamic>.from(legacy);
        final chicken = (m['chickenGrams'] as num?)?.toDouble() ?? 0;
        final fries = (m['friesGrams'] as num?)?.toDouble() ?? 0;
        if (chicken > 0) usage['chicken'] = (usage['chicken'] ?? 0) + chicken * item.qty;
        if (fries > 0) usage['fries'] = (usage['fries'] ?? 0) + fries * item.qty;
      }
    }
  }
  final ingredientRefs = {for (final id in usage.keys) id: _firestore.collection('ingredients').doc(id)};
  final movementRefs = {for (final id in usage.keys) id: _firestore.collection('stock_movements').doc()};
  await _firestore.runTransaction((tx) async {
    final current = await tx.get(orderRef);
    if (!current.exists) return;
    final data = current.data() ?? <String, dynamic>{};
    if (data['status'] == 'cancelled' || data['inventoryDeducted'] == true) return;
    final docs = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final entry in ingredientRefs.entries) { docs[entry.key] = await tx.get(entry.value); }
    for (final entry in ingredientRefs.entries) {
      final doc = docs[entry.key]!;
      if (!doc.exists) throw StateError('Ingredient "${entry.key}" is missing. Add it and set opening stock.');
      final available = (doc.data()?['stockQuantity'] as num? ?? 0).toDouble();
      final required = usage[entry.key]!;
      if (available + 0.000001 < required) {
        throw StateError('Insufficient ${doc.data()?['name'] ?? entry.key}: available ${available.toStringAsFixed(2)}, required ${required.toStringAsFixed(2)}.');
      }
    }
    for (final entry in ingredientRefs.entries) {
      final id = entry.key;
      final doc = docs[id]!;
      final balance = (doc.data()?['stockQuantity'] as num? ?? 0).toDouble() - usage[id]!;
      tx.update(entry.value, {'stockQuantity': balance, 'updatedAt': FieldValue.serverTimestamp()});
      final movement = movementRefs[id]!;
      tx.set(movement, StockMovement(
        id: movement.id, ingredientId: id, type: StockMovementType.consumption,
        quantity: usage[id]!, unitCost: (doc.data()?['averageUnitCost'] as num? ?? 0).toDouble(),
        createdAt: DateTime.now(), referenceId: orderId,
      ).toMap()..['balanceAfter'] = balance);
    }
    tx.update(orderRef, {
      'inventoryDeducted': true, 'inventoryUsage': usage,
      'inventoryReservedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
 }

 Future<void> cancelOrder(String id, String reason) async {
  final orderRef = _orders.doc(id);
  await _firestore.runTransaction((tx) async {
    final orderSnap = await tx.get(orderRef);
    if (!orderSnap.exists) throw StateError('Order not found.');
    final data = orderSnap.data() ?? <String, dynamic>{};
    if (data['status'] == 'cancelled') return;
    if (data['status'] == 'delivered') throw StateError('A delivered order cannot be cancelled. Use a return/refund process.');
    final rawUsage = data['inventoryUsage'];
    final usage = rawUsage is Map ? Map<String, dynamic>.from(rawUsage) : <String, dynamic>{};
    final refs = <String, DocumentReference<Map<String, dynamic>>>{};
    final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    for (final entry in usage.entries) {
      final ingredientId = entry.key.toString();
      refs[ingredientId] = _firestore.collection('ingredients').doc(ingredientId);
    }
    for (final entry in refs.entries) { snapshots[entry.key] = await tx.get(entry.value); }
    for (final entry in refs.entries) {
      final snap = snapshots[entry.key]!;
      if (!snap.exists) throw StateError('Cannot restore missing ingredient ${entry.key}.');
    }
    for (final entry in refs.entries) {
      final ingredientId = entry.key;
      final quantity = (usage[ingredientId] as num? ?? 0).toDouble();
      if (quantity <= 0) continue;
      final snap = snapshots[ingredientId]!;
      final balance = (snap.data()?['stockQuantity'] as num? ?? 0).toDouble() + quantity;
      tx.update(entry.value, {'stockQuantity': balance, 'updatedAt': FieldValue.serverTimestamp()});
      final movement = _firestore.collection('stock_movements').doc();
      tx.set(movement, StockMovement(
        id: movement.id, ingredientId: ingredientId, type: StockMovementType.adjustment,
        quantity: quantity, unitCost: (snap.data()?['averageUnitCost'] as num? ?? 0).toDouble(),
        createdAt: DateTime.now(), referenceId: id,
      ).toMap()..addAll({'reason': 'Cancelled order stock reversal', 'direction': 'in', 'balanceAfter': balance}));
    }
    tx.update(orderRef, {
      'status': OrderStatus.cancelled.name, 'cancelReason': reason,
      'cancelledAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      'inventoryReversed': data['inventoryDeducted'] == true,
    });
  });
 }
 Future<void> deliverOrder(String orderId,PaymentMethod method)async{
  final orderRef=_orders.doc(orderId);final os=await orderRef.get();if(!os.exists)throw StateError('Order not found.');final order=RestaurantOrder.fromDocument(os);
  final usage=<String,double>{};
  for(final item in order.items){final matches=await _menu.where('name',isEqualTo:item.name).limit(1).get();if(matches.docs.isEmpty)continue;final d=matches.docs.first.data();final lines=d['recipeLines'];
   if(lines is List && lines.isNotEmpty){for(final raw in lines.whereType<Map>()){final line=Map<String,dynamic>.from(raw);final id=(line['ingredientId']??'').toString();final q=(line['quantity'] as num?)?.toDouble()??0;if(id.isNotEmpty&&q>0)usage[id]=(usage[id]??0)+q*item.qty;}}
   else {final legacy=d['ingredientUsage'];if(legacy is Map){final m=Map<String,dynamic>.from(legacy);final c=(m['chickenGrams'] as num?)?.toDouble()??0;final f=(m['friesGrams'] as num?)?.toDouble()??0;if(c>0)usage['chicken']=(usage['chicken']??0)+c*item.qty;if(f>0)usage['fries']=(usage['fries']??0)+f*item.qty;}}
  }
  final refs={for(final id in usage.keys)id:_firestore.collection('ingredients').doc(id)};final moves={for(final id in usage.keys)id:_firestore.collection('stock_movements').doc()};
  await _firestore.runTransaction((tx)async{final current=await tx.get(orderRef);if(!current.exists)throw StateError('Order not found.');final data=current.data()??{};if(data['status']=='cancelled')throw StateError('Cancelled orders cannot be delivered.');
   if(data['inventoryDeducted']==true){tx.update(orderRef,{'status':OrderStatus.delivered.name,'paymentMethod':method.name,'deliveredAt':data['deliveredAt']??FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});return;}
   final snaps=<String,DocumentSnapshot<Map<String,dynamic>>>{};for(final e in refs.entries){snaps[e.key]=await tx.get(e.value);}
   for(final e in refs.entries){final s=snaps[e.key]!;if(!s.exists)throw StateError('Create ingredient ' + e.key + ' and set stock before delivery.');final have=(s.data()?['stockQuantity'] as num? ??0).toDouble();final need=usage[e.key]!;if(have+0.000001<need)throw StateError('Insufficient ' + (s.data()?['name']??e.key).toString() + ' stock. Available: ' + have.toString() + ', required: ' + need.toString());}
   for(final e in refs.entries){final id=e.key;final s=snaps[id]!;final need=usage[id]!;final balance=(s.data()?['stockQuantity'] as num? ??0).toDouble()-need;tx.update(e.value,{'stockQuantity':balance,'updatedAt':FieldValue.serverTimestamp()});final mv=moves[id]!;tx.set(mv,StockMovement(id:mv.id,ingredientId:id,type:StockMovementType.consumption,quantity:need,unitCost:(s.data()?['averageUnitCost'] as num? ??0).toDouble(),createdAt:DateTime.now(),referenceId:orderId).toMap()..['balanceAfter']=balance);}
   tx.update(orderRef,{'status':OrderStatus.delivered.name,'paymentMethod':method.name,'deliveredAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp(),'inventoryDeducted':true,'inventoryUsage':usage});
  });
 }
 Future<void> editOrder({required String orderId,required String customerName,required String phone,required String table,required String note,required List<OrderItem> items})async{if(items.isEmpty)throw ArgumentError('An order must contain at least one item.');final total=items.fold<double>(0,(s,i)=>s+i.total);await _orders.doc(orderId).update({'customerName':customerName,'phone':phone,'table':table,'note':note.isEmpty?null:note,'items':items.map((i)=>i.toMap()).toList(),'total':total,'updatedAt':FieldValue.serverTimestamp()});}
 Future<void> createManualOrder({required String customerName,required String phone,required String table,required String note,required List<OrderItem> items})async{final total=items.fold<double>(0,(s,i)=>s+i.total);await _orders.add({'customerName':customerName,'phone':phone,'table':table.isEmpty?'main':table,'items':items.map((i)=>i.toMap()).toList(),'total':total,'status':OrderStatus.pending.name,'note':note.isEmpty?null:note,'category':'Manual','source':'manual','createdAt':FieldValue.serverTimestamp(),'kocPrinted':false,'kocPrintedAt':null,'paymentMethod':null});}
 Future<void> saveMenuItem({String? id,required String name,required double price,required String category,required String description,required String emoji,required String tag,required bool isAvailable,double chickenGrams=0,double friesGrams=0,List<Map<String,dynamic>> recipeLines=const []})async{final doc=id==null?_menu.doc():_menu.doc(id);await doc.set({'name':name,'price':price,'category':category,'description':description,'emoji':emoji.isEmpty?'🍽️':emoji,'tag':tag,'isAvailable':isAvailable,'recipeLines':recipeLines,'ingredientUsage':{'chickenGrams':chickenGrams,'friesGrams':friesGrams},'updatedAt':FieldValue.serverTimestamp(),if(id==null)'createdAt':FieldValue.serverTimestamp()},SetOptions(merge:true));}
 Future<void> setMenuAvailability(String id,bool available)=>_menu.doc(id).update({'isAvailable':available});
 Future<void> deleteMenuItem(String id)=>_menu.doc(id).delete();
}