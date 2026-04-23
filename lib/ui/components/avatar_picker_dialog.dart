import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/profile_provider.dart';

class AvatarPickerDialog extends ConsumerStatefulWidget {
  const AvatarPickerDialog({super.key});

  @override
  ConsumerState<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends ConsumerState<AvatarPickerDialog> {
  bool _isLoading = false;

  final List<String> _templates = List.generate(8, (i) => "assets/avatars/avatar_${i + 1}.png");

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery, 
      maxWidth: 512, 
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() => _isLoading = true);
    await ref.read(profileProvider.notifier).updateAvatar(File(image.path));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickTemplate(String assetPath) async {
    setState(() => _isLoading = true);
    
    try {
      // Convert asset to File
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${assetPath.split('/').last}');
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
      
      await ref.read(profileProvider.notifier).updateAvatar(file);
    } catch (e) {
      debugPrint("Error picking template: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.failedToSetAvatar))
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
             BoxShadow(
               color: Colors.black.withValues(alpha: 0.2),
               blurRadius: 20,
               spreadRadius: 2,
             ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.chooseAvatar,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_isLoading)
              const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Grid of templates
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final path = _templates[index];
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () => _pickTemplate(path),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                            ),
                            image: DecorationImage(
                              image: AssetImage(path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              
              // Custom Import Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(AppLocalizations.of(context)!.importFromGallery, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              
              // Remove Avatar Button
              if (ref.read(profileProvider).avatarUrl != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      setState(() => _isLoading = true);
                      await ref.read(profileProvider.notifier).removeAvatar();
                      if (mounted) Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: Text(AppLocalizations.of(context)!.removeAvatar, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
