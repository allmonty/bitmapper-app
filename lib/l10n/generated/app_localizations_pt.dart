// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Bitmapper';

  @override
  String windowTitle(String name) {
    return 'Bitmapper - $name';
  }

  @override
  String get untitled => '(sem título)';

  @override
  String get menuFile => 'Arquivo';

  @override
  String get menuOpen => 'Abrir...';

  @override
  String get menuCamera => 'Tirar foto...';

  @override
  String get menuSave => 'Salvar como...';

  @override
  String get menuClose => 'Fechar imagem';

  @override
  String get menuPresets => 'Predefinições';

  @override
  String get menuSavePreset => 'Salvar atual...';

  @override
  String get menuHelp => 'Ajuda';

  @override
  String get menuAbout => 'Sobre o Bitmapper...';

  @override
  String get emptyTitle => 'Abra uma imagem';

  @override
  String get emptyBody => 'Escolha uma foto para virar pixel art retrô.';

  @override
  String get emptyGallery => 'Galeria...';

  @override
  String get emptyCamera => 'Câmera...';

  @override
  String get holdToCompare => 'Segure para comparar';

  @override
  String get tabPalette => 'Paleta';

  @override
  String get tabDither => 'Dither';

  @override
  String get tabGrid => 'Grade';

  @override
  String get tabAdjust => 'Ajustes';

  @override
  String get tabEffects => 'Efeitos';

  @override
  String get tabPresets => 'Predef.';

  @override
  String get paletteMode => 'Modo';

  @override
  String get paletteAuto => 'Automática (da imagem)';

  @override
  String get paletteFixed => 'Fixa';

  @override
  String get paletteCustom => 'Personalizada';

  @override
  String get paletteAlgorithm => 'Algoritmo';

  @override
  String get algoMedianCut => 'Corte mediano';

  @override
  String get algoKmeans => 'K-médias';

  @override
  String get fixedPalette => 'Paleta';

  @override
  String get colorsGroup => 'Cores';

  @override
  String bitDepth(int bits, int colors) {
    return 'Profundidade: $bits bits ($colors cores)';
  }

  @override
  String get trueColor => 'Cor real (sem quantizar)';

  @override
  String get customColors => 'Cores personalizadas';

  @override
  String get addColor => 'Adicionar...';

  @override
  String get editColor => 'Editar...';

  @override
  String get removeColor => 'Remover';

  @override
  String get ditherMethod => 'Método';

  @override
  String ditherStrength(int percent) {
    return 'Intensidade: $percent%';
  }

  @override
  String gridColumns(int cols) {
    return 'Colunas de pixels: $cols';
  }

  @override
  String get gridSampling => 'Amostragem do bloco';

  @override
  String get samplingAverage => 'Média';

  @override
  String get samplingNearest => 'Mais próximo (centro)';

  @override
  String gridGap(int px) {
    return 'Espaço da grade: $px px';
  }

  @override
  String get gridGapColor => 'Cor do espaço...';

  @override
  String adjustContrast(String value) {
    return 'Contraste: $value';
  }

  @override
  String adjustSaturation(String value) {
    return 'Saturação: $value';
  }

  @override
  String adjustGamma(String value) {
    return 'Gama: $value';
  }

  @override
  String get reset => 'Redefinir';

  @override
  String effectScanlines(int percent) {
    return 'Linhas de varredura: $percent%';
  }

  @override
  String get presetsApply => 'Aplicar';

  @override
  String get presetsSave => 'Salvar atual...';

  @override
  String get presetsRename => 'Renomear...';

  @override
  String get presetsDelete => 'Excluir';

  @override
  String presetBuiltIn(String name) {
    return '$name (padrão)';
  }

  @override
  String get presetNameTitle => 'Salvar predefinição';

  @override
  String get presetNamePrompt => 'Nome da predefinição:';

  @override
  String get presetDefaultName => 'Minha predefinição';

  @override
  String get renameTitle => 'Renomear predefinição';

  @override
  String get deleteTitle => 'Excluir predefinição';

  @override
  String deleteConfirm(String name) {
    return 'Excluir \"$name\"?';
  }

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get yes => 'Sim';

  @override
  String get no => 'Não';

  @override
  String get statusReady => 'Pronto';

  @override
  String get statusNoImage => 'Sem imagem';

  @override
  String statusCells(int cols, int rows) {
    return '$cols×$rows células';
  }

  @override
  String statusColors(int count) {
    return '$count cores';
  }

  @override
  String statusMs(int ms) {
    return '$ms ms';
  }

  @override
  String get statusWorking => 'Processando...';

  @override
  String statusSaved(String name) {
    return '$name salvo';
  }

  @override
  String get statusSaving => 'Salvando...';

  @override
  String get savingTitle => 'Salvando';

  @override
  String get savingBody => 'Gerando a imagem em tamanho real...';

  @override
  String get errorTitle => 'Bitmapper';

  @override
  String get errorLoad => 'Não foi possível abrir essa imagem.';

  @override
  String get errorSave => 'Não foi possível salvar a imagem.';

  @override
  String get errorFilter => 'Não foi possível aplicar o filtro.';

  @override
  String get aboutTitle => 'Sobre o Bitmapper';

  @override
  String aboutBody(String version) {
    return 'Bitmapper $version\nUm filtro de fotos em pixel art retrô.';
  }
}
