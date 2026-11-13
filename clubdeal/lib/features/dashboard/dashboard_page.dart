import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/bloc/app_bloc.dart';
import '../../core/bloc/expense_bloc.dart';
import '../../core/bloc/order_bloc.dart';
import '../../core/models/order_model.dart';
import '../../core/utils/currency_utils.dart';
import '../orders/order_tile.dart';
import '../widgets/desktop_widgets.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  String _dayKey(DateTime d) => '${d.year.toString().padLeft(4,'0')}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';

  Future<void> _setOpeningCash(BuildContext context) async {
    final controller=TextEditingController();
    final form=GlobalKey<FormState>();
    final value=await showDialog<double>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Opening cash in counter'),
      content:Form(key:form,child:TextFormField(controller:controller,autofocus:true,keyboardType:const TextInputType.numberWithOptions(decimal:true),
        decoration:const InputDecoration(labelText:'Cash float at start of day (₹)',hintText:'e.g. 2000'),
        validator:(v){final n=double.tryParse(v??'');return n==null||n<0?'Enter a valid amount':null;})),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>form.currentState?.validate()==true?Navigator.pop(ctx,double.parse(controller.text)):null,child:const Text('Save opening cash'))],
    ));
    controller.dispose();
    if(value==null)return;
    final now=DateTime.now();
    await FirebaseFirestore.instance.collection('cash_sessions').doc(_dayKey(now)).set({
      'dateKey':_dayKey(now),'openingCash':value,'openedAt':FieldValue.serverTimestamp(),
    },SetOptions(merge:true));
  }

  @override
  Widget build(BuildContext context) {
    final now=DateTime.now();
    final start=DateTime(now.year,now.month,now.day);
    final key=_dayKey(now);
    return BlocBuilder<OrderBloc,OrderState>(builder:(context,ordersState)=>
      BlocBuilder<ExpenseBloc,ExpenseState>(builder:(context,expenseState){
        final todays=ordersState.orders.where((o)=>o.createdAt!=null && !o.createdAt!.isBefore(start) && o.createdAt!.isBefore(start.add(const Duration(days:1)))).toList();
        final paid=todays.where((o)=>o.status==OrderStatus.delivered && o.paymentMethod!=null).toList();
        double sum(PaymentMethod m)=>paid.where((o)=>o.paymentMethod==m).fold(0.0,(a,o)=>a+o.total);
        final cash=sum(PaymentMethod.cash), card=sum(PaymentMethod.card), online=sum(PaymentMethod.online);
        final income=cash+card+online;
        final expenses=expenseState.items.where((e)=>e.createdAt.year==now.year&&e.createdAt.month==now.month&&e.createdAt.day==now.day).fold<double>(0,(a,e)=>a+e.amount);
        final active=ordersState.orders.where((o)=>o.status!=OrderStatus.delivered&&o.status!=OrderStatus.cancelled).toList();
        final pending=active.where((o)=>o.status==OrderStatus.pending).length;
        return ListView(padding:const EdgeInsets.all(24),children:[
          const PageTitle(title:'Dashboard',subtitle:'Today at a glance — orders, collections and expenses'),
          const SizedBox(height:16),
          StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
            stream:FirebaseFirestore.instance.collection('cash_sessions').doc(key).snapshots(),
            builder:(context,snapshot){
              final opening=(snapshot.data?.data()?['openingCash'] as num? ?? 0).toDouble();
              return Card(child:Padding(padding:const EdgeInsets.all(16),child:Row(children:[
                const Icon(Icons.point_of_sale,color:AppColors.gold,size:26),const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  const Text('Opening cash in counter',style:TextStyle(color:AppColors.muted,fontSize:12)),
                  Text(formatInr(opening),style:const TextStyle(fontSize:22,fontWeight:FontWeight.w800,color:AppColors.cream)),
                ])),
                OutlinedButton.icon(onPressed:()=>_setOpeningCash(context),icon:const Icon(Icons.edit_outlined,size:16),label:Text(snapshot.data?.exists==true?'Update':'Set opening cash')),
              ])));
            }),
          const SizedBox(height:12),
          GridView.count(crossAxisCount:4,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:2.0,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),children:[
            MetricCard(label:'Orders today',value:'${todays.length}',icon:Icons.receipt_long_outlined),
            MetricCard(label:'Active orders',value:'${active.length}',icon:Icons.local_fire_department_outlined),
            MetricCard(label:'Total income',value:formatInr(income),icon:Icons.account_balance_wallet_outlined),
            MetricCard(label:'Expenses today',value:formatInr(expenses),icon:Icons.money_off_outlined),
            MetricCard(label:'Cash sales',value:formatInr(cash),icon:Icons.payments_outlined),
            MetricCard(label:'Card sales',value:formatInr(card),icon:Icons.credit_card_outlined),
            MetricCard(label:'Online / UPI',value:formatInr(online),icon:Icons.qr_code_2_outlined),
            MetricCard(label:'Income after expenses',value:formatInr(income-expenses),icon:Icons.trending_up),
          ]),
          const SizedBox(height:12),
          StreamBuilder<DocumentSnapshot<Map<String,dynamic>>>(
            stream:FirebaseFirestore.instance.collection('cash_sessions').doc(key).snapshots(),
            builder:(context,snapshot){
              final opening=(snapshot.data?.data()?['openingCash'] as num? ?? 0).toDouble();
              return Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
                const Icon(Icons.account_balance_wallet_outlined,color:AppColors.success),
                const SizedBox(width:10),
                const Expanded(child:Text('Expected cash in counter',style:TextStyle(fontWeight:FontWeight.w700))),
                Text(formatInr(opening+cash),style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800,color:AppColors.success)),
              ])));
            }),
          const SizedBox(height:20),
          Row(children:[const Expanded(child:Text('Live Orders',style:TextStyle(color:AppColors.cream,fontSize:17,fontWeight:FontWeight.w700))),
            Text('$pending waiting • ${active.length} active',style:const TextStyle(color:AppColors.muted,fontSize:11))]),
          const SizedBox(height:10),
          if(ordersState.loading) const LinearProgressIndicator(minHeight:2)
          else if(active.isEmpty) const SizedBox(height:180,child:EmptyPanel(title:'No active orders',message:'New orders will appear here automatically.'))
          else ...active.take(8).map((order)=>Padding(padding:const EdgeInsets.only(bottom:8),child:OrderTile(order:order))),
          const SizedBox(height:16),
          OutlinedButton.icon(onPressed:()=>context.read<AppBloc>().add(const AppPageChanged(DesktopPage.activeOrders)),
            icon:const Icon(Icons.receipt_long_outlined,size:17),label:const Text('Open Active Orders')),
        ]);
      }),
    );
  }
}
