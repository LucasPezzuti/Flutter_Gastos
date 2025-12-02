import 'package:flutter/material.dart';
import '../services/firebase_sync_service.dart';

/// Widget que muestra una barra de progreso de sincronización
/// 
/// Se muestra únicamente cuando hay un sync en progreso (1-99%)
/// Desaparece cuando el sync termina (0% o 100%)
class SyncProgressBar extends StatelessWidget {
  final Color? backgroundColor;
  final Color? progressColor;

  const SyncProgressBar({
    super.key,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: FirebaseSyncService.syncProgressStream,
      initialData: 0,
      builder: (context, snapshot) {
        final progress = snapshot.data ?? 0;
        
        // No mostrar si está en 0% o 100%
        if (progress == 0 || progress == 100) {
          return SizedBox.shrink();
        }

        final percentage = progress / 100;
        
        return Container(
          height: 4,
          color: backgroundColor ?? Colors.grey[300],
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Column(
              children: [
                Expanded(
                  flex: progress,
                  child: Container(
                    color: progressColor ?? Theme.of(context).primaryColor,
                  ),
                ),
                Expanded(
                  flex: 100 - progress,
                  child: Container(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget que combina la barra de progreso con un indicador de texto
class SyncProgressIndicator extends StatelessWidget {
  final Color? backgroundColor;
  final Color? progressColor;

  const SyncProgressIndicator({
    super.key,
    this.backgroundColor,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: FirebaseSyncService.syncProgressStream,
      initialData: 0,
      builder: (context, snapshot) {
        final progress = snapshot.data ?? 0;
        
        // No mostrar si está en 0% o 100%
        if (progress == 0 || progress == 100) {
          return SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Sincronizando...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '$progress%',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  backgroundColor: backgroundColor ?? Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progressColor ?? Theme.of(context).primaryColor,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
