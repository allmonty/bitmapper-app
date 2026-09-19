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
  String get menuCamera => 'Câmera...';

  @override
  String get menuSave => 'Salvar como...';

  @override
  String get menuClose => 'Fechar';

  @override
  String get menuPresets => 'Predefinições';

  @override
  String get menuSavePreset => 'Salvar atual...';

  @override
  String get menuHelp => 'Ajuda';

  @override
  String get menuAbout => 'Sobre o Bitmapper...';

  @override
  String get emptyTitle => 'Abra uma foto ou vídeo';

  @override
  String get emptyBody => 'Escolha uma foto, GIF ou vídeo para virar pixel art retrô.';

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
  String get errorLoad => 'Não foi possível abrir esse arquivo.';

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

  @override
  String get tabAnimation => 'Animação';

  @override
  String frameLabel(int current, int total) {
    return 'Quadro $current / $total';
  }

  @override
  String get paletteAcrossFrames => 'Paleta entre quadros';

  @override
  String get strategyFirst => 'Primeiro quadro';

  @override
  String get strategySampled => 'Quadros amostrados';

  @override
  String get strategyPerFrame => 'Cada quadro (pode piscar)';

  @override
  String paletteSamples(int count) {
    return 'Amostras: $count quadros';
  }

  @override
  String get strategyOnlyAuto => 'Só se aplica a paletas automáticas.';

  @override
  String get animateNoise => 'Animar ruído aleatório';

  @override
  String get gifSize => 'Tamanho do GIF';

  @override
  String gifOriginal(int width, int height) {
    return 'Tamanho original ($width×$height)';
  }

  @override
  String get gifPerCell => 'Pixels por célula';

  @override
  String gifPerCellValue(int pixels, int width, int height) {
    return '$pixels px por célula ($width×$height)';
  }

  @override
  String get animationFriendly => 'Usar ajustes para animação';

  @override
  String get animationFriendlyHint =>
      'Uma paleta amostrada entre quadros e dither ordenado, que ficam estáveis entre quadros.';

  @override
  String get statusShimmer => 'O dither pode tremular entre quadros';

  @override
  String get exportTitle => 'Salvando animação';

  @override
  String exportProgress(int done, int total) {
    return 'Quadro $done de $total';
  }

  @override
  String get exportPreparing => 'Preparando...';

  @override
  String statusSavedLossy(String name) {
    return '$name salvo (alguns quadros reduzidos a 256 cores)';
  }

  @override
  String get gifColorLimit =>
      'GIF suporta até 256 cores por quadro; paletas maiores são reduzidas ao salvar.';

  @override
  String animationTruncated(int count) {
    return 'Este GIF é longo, então só os primeiros $count quadros foram carregados.';
  }

  @override
  String get exportFormat => 'Salvar como';

  @override
  String get formatMp4 => 'Vídeo MP4 (com som)';

  @override
  String get formatGif => 'GIF animado (sem som)';

  @override
  String get mp4Resolution => 'Resolução';

  @override
  String get resOriginal => 'Tamanho original';

  @override
  String get res720 => '720p';

  @override
  String get res480 => '480p';

  @override
  String gifFrameRate(int fps) {
    return 'Taxa do GIF: $fps qps';
  }

  @override
  String get exportVideoTitle => 'Salvando vídeo';

  @override
  String get statusSampling => 'Amostrando quadros...';

  @override
  String get audioUnsupported =>
      'O som deste vídeo usa um formato que não pode ser copiado para MP4, então os vídeos salvos ficarão sem som. A imagem não é afetada.';

  @override
  String get audioUnsupportedShort =>
      'O som deste vídeo não pode ser mantido; o MP4 ficará sem som.';

  @override
  String statusSavedNoSound(String name) {
    return '$name salvo (sem som)';
  }

  @override
  String get emptyOpen => 'Abrir...';

  @override
  String get cameraTitle => 'Câmera';

  @override
  String get cameraPrompt => 'Tirar uma foto ou gravar um vídeo?';

  @override
  String get cameraPhoto => 'Foto';

  @override
  String get cameraVideo => 'Vídeo';

  @override
  String effectOutline(int percent) {
    return 'Contorno: $percent%';
  }

  @override
  String get toonGroup => 'Desenho animado';

  @override
  String effectShadeBands(int bands) {
    return 'Faixas de sombra: $bands';
  }

  @override
  String get effectShadeBandsOff => 'Faixas de sombra: desligado';

  @override
  String get effectDespeckle => 'Limpar pixels soltos';

  @override
  String get outlineMethod => 'Bordas do contorno';

  @override
  String get outlineInk => 'Tinta do contorno';
}
