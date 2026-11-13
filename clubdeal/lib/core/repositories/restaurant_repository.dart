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
 Future<void> cancelOrder(String id,String reason)async{await _orders.doc(id).update({'status':OrderStatus.cancelled.name,'cancelReason':reason,'cancelledAt':FieldValue.serverTimestamp(),'updatedAt':FieldValue.serverTimestamp()});}
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