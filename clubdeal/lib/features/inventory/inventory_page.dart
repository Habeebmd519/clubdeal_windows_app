import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/bloc/inventory_bloc.dart';
import '../../core/utils/currency_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/desktop_widgets.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        final lowStock = state.items.where(
          (item) => item.stockQuantity <= item.lowStockThreshold,
        ).length;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle(
                title: 'Inventory',
                subtitle: 'Ingredient stock and average purchase cost',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      label: 'Ingredients',
                      value: '${state.items.length}',
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MetricCard(
                      label: 'Low stock',
                      value: '$lowStock',
                      icon: Icons.warning_amber_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.loading && state.items.isEmpty)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (state.error != null)
                Expanded(child: Center(child: Text('Could not load inventory: ${state.error}')))
              else if (state.items.isEmpty)
                const Expanded(
                  child: EmptyPanel(
                    title: 'No ingredients yet',
                    message: 'Ingredient records will appear here once added to the ingredients collection.',
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      final isLow = item.stockQuantity <= item.lowStockThreshold;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.grass_outlined, color: AppColors.gold),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.w600)),
                                  Text('Average cost: ${formatInr(item.averageUnitCost)} / ${item.baseUnit}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(
                              '${item.stockQuantity.toStringAsFixed(2)} ${item.baseUnit}',
                              style: TextStyle(
                                color: isLow ? AppColors.warning : AppColors.cream,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
