part of '../home.dart';

extension _ProfilePageView on _HomeState {
  Future<void> _openProfile() async {
    if (_email == null) return;
    Map<String, dynamic> profile = _profile;
    try {
      profile = Map<String, dynamic>.from(
        await _request('GET', '/auth/profile/${Uri.encodeComponent(_email!)}'),
      );
    } catch (error) {
      _toast('$error');
    }
    final name = TextEditingController(text: '${profile['c_name'] ?? ''}');
    final phone = TextEditingController(text: '${profile['tel'] ?? ''}');
    final address = TextEditingController(
      text: '${profile['c_address'] ?? ''}',
    );
    final gender = TextEditingController(text: '${profile['c_gender'] ?? ''}');
    var sizeValue = '';
    if (_localAvailable) {
      try {
        final rows = await LocalDatabase.instance.queryRecords(
          LocalDatabase.customer,
          where: 'mail = ?',
          whereArgs: [_email],
        );
        if (rows.isNotEmpty) sizeValue = '${rows.first['size']}';
      } catch (_) {}
    }
    final size = TextEditingController(text: sizeValue);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Scaffold(
          appBar: AppBar(title: const Text('내 정보 변경')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              const Text(
                '나를 위한 쇼핑 정보',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text('이메일은 계정 식별값이며 변경할 수 없습니다.'),
              _field(name, '이름'),
              _field(phone, '휴대폰 번호', keyboard: TextInputType.phone),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: '이메일'),
                  child: Text(_email!),
                ),
              ),
              _field(address, '주소'),
              _field(gender, '성별'),
              _field(
                size,
                '내 신발 사이즈 (이 기기에 저장)',
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  try {
                    await _request(
                      'PUT',
                      '/auth/profile/${Uri.encodeComponent(_email!)}',
                      body: {
                        'c_name': name.text.trim(),
                        'tel': phone.text.trim(),
                        'c_address': address.text.trim(),
                        'c_gender': gender.text.trim(),
                      },
                    );
                    if (_localAvailable && size.text.trim().isNotEmpty) {
                      await LocalDatabase.instance.insertRecord(
                        LocalDatabase.customer,
                        {'mail': _email!, 'size': size.text.trim()},
                        conflictAlgorithm: __conflictReplace,
                      );
                    }
                    if (!pageContext.mounted) return;
                    _updateState(
                      () => _profile = {
                        ...profile,
                        'c_name': name.text.trim(),
                        'tel': phone.text.trim(),
                        'c_address': address.text.trim(),
                        'c_gender': gender.text.trim(),
                      },
                    );
                    Navigator.pop(pageContext);
                    _toast('회원 정보가 저장되었습니다.');
                  } catch (error) {
                    _toast('$error');
                  }
                },
                child: const Text('변경 내용 저장'),
              ),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    phone.dispose();
    address.dispose();
    gender.dispose();
    size.dispose();
  }
}
