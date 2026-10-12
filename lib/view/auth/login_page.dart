part of '../home.dart';

extension _LoginPageView on _HomeState {
  Widget _authPage() => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 30),
        const Text(
          'FITPICK',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 24),
        Text(
          _signingUp ? '회원가입' : '로그인',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (_signingUp) ...[
          _field(_nameInput, '이름'),
          _field(_phoneInput, '전화번호', keyboard: TextInputType.phone),
          _field(_genderInput, '성별'),
          _field(_addressInput, '주소'),
          _field(_sizeInput, '신발 사이즈', keyboard: TextInputType.number),
        ],
        _field(_emailInput, '이메일', keyboard: TextInputType.emailAddress),
        _field(_passwordInput, '비밀번호', obscure: true),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_message!, style: const TextStyle(color: Colors.red)),
          ),
        FilledButton(
          onPressed: _busy ? null : _authenticate,
          child: _busy
              ? const CircularProgressIndicator()
              : Text(_signingUp ? '가입하기' : '로그인'),
        ),
        TextButton(
          onPressed: () => _updateState(() {
            _signingUp = !_signingUp;
            _message = null;
          }),
          child: Text(_signingUp ? '이미 회원이신가요? 로그인' : '아직 회원이 아니신가요? 회원가입'),
        ),
        TextButton(
          onPressed: () => _updateState(() => _tab = 0),
          child: const Text('비회원으로 상품 둘러보기'),
        ),
      ],
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool obscure = false,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  Widget _loginGate() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock_outline, size: 42),
        const SizedBox(height: 12),
        const Text('로그인 후 이용할 수 있어요.'),
        const SizedBox(height: 8),
        FilledButton(onPressed: _goLogin, child: const Text('로그인하기')),
      ],
    ),
  );
}
