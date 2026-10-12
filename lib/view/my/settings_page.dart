part of '../home.dart';

extension _SettingsPageView on _HomeState {
  Future<void> _openSettings() async {
    var darkMode = widget.darkMode;
    var fontScale = widget.fontScale;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (context, refresh) => Scaffold(
            appBar: AppBar(title: const Text('앱 설정')),
            body: ListView(
              children: [
                SwitchListTile(
                  title: const Text('다크 모드'),
                  subtitle: const Text('화면 색상을 어둡게 표시합니다.'),
                  value: darkMode,
                  onChanged: (value) {
                    refresh(() => darkMode = value);
                    widget.onSettingsChanged(value, fontScale);
                  },
                ),
                ListTile(
                  title: const Text('글자 크기'),
                  subtitle: Text('${(fontScale * 100).round()}%'),
                ),
                Slider(
                  value: fontScale,
                  min: 0.85,
                  max: 1.25,
                  divisions: 8,
                  label: '${(fontScale * 100).round()}%',
                  onChanged: (value) {
                    refresh(() => fontScale = value);
                    widget.onSettingsChanged(darkMode, value);
                  },
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('설정은 이 기기에 저장됩니다.'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
