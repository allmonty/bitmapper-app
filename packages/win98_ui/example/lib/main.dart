import 'package:flutter/widgets.dart';
import 'package:win98_ui/win98_ui.dart';

void main() => runApp(const GalleryApp());

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'win98_ui gallery',
      color: const Color(0xFF008080),
      debugShowCheckedModeBanner: false,
      builder: (context, navigator) => Win98Theme(child: navigator!),
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) =>
          PageRouteBuilder<T>(settings: settings, pageBuilder: (c, _, _) => builder(c)),
      home: const Gallery(),
    );
  }
}

class Gallery extends StatefulWidget {
  const Gallery({super.key});

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  bool _checked = true;
  String _radio = 'average';
  double _slider = 0.5;
  String _dropdown = 'floyd_steinberg';
  String? _listSelection = 'Gameboy';
  Color _color = const Color(0xFF008080);
  final _text = TextEditingController(text: 'Hello, 1998');

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _about() =>
      showWin98MessageBox(context: context, title: 'About', message: 'win98_ui gallery');

  @override
  Widget build(BuildContext context) {
    return Win98Desktop(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Win98Window(
            title: 'win98_ui gallery',
            expand: true,
            onClose: _about,
            menuBar: Win98MenuBar(
              menus: [
                Win98Menu(
                  label: 'File',
                  items: [
                    Win98MenuItem(label: 'About...', onSelected: _about),
                    const Win98MenuDivider(),
                    const Win98MenuItem(label: 'Exit'),
                  ],
                ),
              ],
            ),
            statusBar: Win98StatusBar(
              panes: [
                const Win98StatusPane(Text('Ready'), flex: 2),
                Win98StatusPane(Text('${(_slider * 100).round()}%')),
              ],
            ),
            child: Win98TabView(
              tabs: [
                Win98Tab(label: 'Controls', builder: (_) => _controls()),
                Win98Tab(label: 'Lists', builder: (_) => _lists()),
                Win98Tab(label: 'Dialogs', builder: (_) => _dialogs()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() => Win98ScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Win98GroupBox(
          label: 'Toggles',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Win98Checkbox(
                value: _checked,
                label: 'Checkbox',
                onChanged: (v) => setState(() => _checked = v),
              ),
              for (final v in ['average', 'nearest'])
                Win98Radio<String>(
                  value: v,
                  groupValue: _radio,
                  label: v,
                  onChanged: (x) => setState(() => _radio = x),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Win98Slider(value: _slider, divisions: 10, onChanged: (v) => setState(() => _slider = v)),
        Win98ProgressBar(value: _slider),
        const SizedBox(height: 8),
        Win98Dropdown<String>(
          value: _dropdown,
          items: const [
            Win98DropdownItem(value: 'none', label: 'None'),
            Win98DropdownItem(value: 'floyd_steinberg', label: 'Floyd-Steinberg'),
            Win98DropdownItem(value: 'atkinson', label: 'Atkinson'),
          ],
          onChanged: (v) => setState(() => _dropdown = v),
        ),
        const SizedBox(height: 8),
        Win98TextField(controller: _text),
        const SizedBox(height: 8),
        Row(
          children: [
            Win98Button(isDefault: true, onPressed: () {}, child: const Text('OK')),
            const SizedBox(width: 6),
            const Win98Button(onPressed: null, child: Text('Disabled')),
          ],
        ),
      ],
    ),
  );

  Widget _lists() => Win98ListBox<String>(
    height: 220,
    items: [
      for (final name in ['Gameboy', 'CGA', 'EGA', 'C64', 'NES', 'PICO-8', 'Teletext', 'Sepia'])
        Win98ListItem(value: name, label: name),
    ],
    selected: _listSelection,
    onSelected: (v) => setState(() => _listSelection = v),
  );

  Widget _dialogs() => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final icon in Win98MessageIconType.values)
        Win98Button(
          onPressed: () => showWin98MessageBox(
            context: context,
            title: icon.name,
            message: 'A ${icon.name} message.',
            icon: icon,
            buttons: const ['OK', 'Cancel'],
          ),
          child: Text(icon.name),
        ),
      Win98Button(
        onPressed: () async {
          final c = await showWin98ColorDialog(context: context, initial: _color);
          if (c != null) setState(() => _color = c);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 14, height: 14, child: ColoredBox(color: _color)),
            const SizedBox(width: 6),
            const Text('Color...'),
          ],
        ),
      ),
    ],
  );
}
