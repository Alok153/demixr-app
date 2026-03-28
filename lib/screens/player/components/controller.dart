import 'package:demixr_app/constants.dart';
import 'package:demixr_app/providers/library_provider.dart';
import 'package:demixr_app/providers/player_provider.dart';
import 'package:demixr_app/screens/player/components/controller_button.dart';
import 'package:demixr_app/screens/player/components/song_progress_bar.dart';
import 'package:demixr_app/screens/player/components/stem_selection.dart';
import 'package:demixr_app/services/audio_export_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

import '../../../utils.dart';

class Controller extends StatelessWidget {
  const Controller({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        StemSelection(),
        SongController(),
      ],
    );
  }
}

class SongController extends StatelessWidget {
  const SongController({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const radius = Radius.circular(35);
    return SizedBox(
      height: 180,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: ColorPalette.surfaceVariant,
          borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 20, right: 20),
              child: SongProgressBar(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ControllerButton(
                  SvgPicture.asset(getAssetPath('previous', AssetType.icon)),
                  gradient: ColorPalette.primaryFadedGradient,
                  size: 55,
                  onPressed: () => context.read<PlayerProvider>().previous(),
                ),
                Consumer<PlayerProvider>(
                  builder: (context, player, child) {
                    final icon = player.isPlaying
                        ? const Icon(
                            Icons.pause,
                            color: Colors.white,
                            size: 35,
                          )
                        : SvgPicture.asset(
                            getAssetPath('play', AssetType.icon),
                          );

                    return ControllerButton(
                      icon,
                      onPressed: () => player.playpause(),
                    );
                  },
                ),
                ControllerButton(
                  SvgPicture.asset(getAssetPath('next', AssetType.icon)),
                  gradient: ColorPalette.primaryFadedGradient,
                  size: 55,
                  onPressed: () => context.read<PlayerProvider>().next(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _ExportButton(),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatefulWidget {
  const _ExportButton();

  @override
  State<_ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<_ExportButton> {
  final _audioExportService = AudioExportService();

  Future<void> _exportStems() async {
    final library = context.read<LibraryProvider>();

    await library.currentSong.fold(
      (_) async {
        errorSnackbar('Export failed', 'No song selected to export.');
      },
      (song) async {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );

        try {
          final exportedPath = await _audioExportService.exportStems(song);
          Get.back();
          Get.snackbar(
            'Export complete',
            'Stems saved to $exportedPath',
            backgroundColor: ColorPalette.surfaceVariant,
            colorText: ColorPalette.onSurface,
          );
        } on AudioExportException catch (error) {
          Get.back();
          errorSnackbar('Export failed', error.message, seconds: 4);
        } catch (_) {
          Get.back();
          errorSnackbar('Export failed', 'Unexpected error while exporting.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: ElevatedButton.icon(
        onPressed: _exportStems,
        icon: const Icon(Icons.download_rounded),
        label: const Text('Export stems'),
        style: ElevatedButton.styleFrom(
          primary: ColorPalette.primary,
          onPrimary: ColorPalette.onPrimary,
        ),
      ),
    );
  }
}
