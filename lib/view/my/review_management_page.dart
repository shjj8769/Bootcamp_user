part of '../home.dart';

extension _ReviewManagementPageView on _HomeState {
  Future<void> _openMyReviews() async {
    if (_email == null) return;
    Future<dynamic> reviewsFuture = _request(
      'GET',
      '/review/customer/${Uri.encodeComponent(_email!)}',
    );

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatefulBuilder(
          builder: (context, refreshPage) => Scaffold(
            appBar: AppBar(title: const Text('작성한 리뷰')),
            body: FutureBuilder<dynamic>(
              future: reviewsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('리뷰를 불러오지 못했습니다: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () => refreshPage(
                            () => reviewsFuture = _request(
                              'GET',
                              '/review/customer/${Uri.encodeComponent(_email!)}',
                            ),
                          ),
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }
                final rows = (snapshot.data['results'] as List? ?? const [])
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .toList();
                if (rows.isEmpty) {
                  return const Center(child: Text('작성한 리뷰가 없습니다.'));
                }
                return SlidableAutoCloseBehavior(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      return Slidable(
                        key: ValueKey('review-${row['r_seq']}'),
                        // Swipe right-to-left to reveal the destructive action.
                        endActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: .25,
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                if (await _confirmReviewDelete(context) &&
                                    await _deleteReview(row)) {
                                  refreshPage(
                                    () => reviewsFuture = _request(
                                      'GET',
                                      '/review/customer/${Uri.encodeComponent(_email!)}',
                                    ),
                                  );
                                }
                              },
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.error,
                              foregroundColor: Colors.white,
                              icon: Icons.delete_outline,
                              label: '삭제',
                            ),
                          ],
                        ),
                        // Swipe left-to-right to open the review editor.
                        startActionPane: ActionPane(
                          motion: const DrawerMotion(),
                          extentRatio: .25,
                          children: [
                            SlidableAction(
                              onPressed: (_) async {
                                if (await _editReview(row)) {
                                  refreshPage(
                                    () => reviewsFuture = _request(
                                      'GET',
                                      '/review/customer/${Uri.encodeComponent(_email!)}',
                                    ),
                                  );
                                }
                              },
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              icon: Icons.edit_outlined,
                              label: '수정',
                            ),
                          ],
                        ),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            leading: _reviewThumbnail(row),
                            title: Text('${row['pr_name'] ?? row['SKU']}'),
                            subtitle: Text(
                              '★ ${row['rating']} · ${row['color'] ?? ''} ${row['size'] ?? ''} mm\n${row['post'] ?? ''}',
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            onTap: () {
                              final product = _products
                                  .where((item) => item.sku == '${row['SKU']}')
                                  .firstOrNull;
                              if (product != null) _openProduct(product);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _reviewThumbnail(Map<String, dynamic> review) {
    final imageUrl = review['image_url'];
    if (imageUrl is String && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.rate_review_outlined),
        ),
      );
    }
    return const CircleAvatar(child: Icon(Icons.rate_review_outlined));
  }

  Future<bool> _confirmReviewDelete(BuildContext pageContext) async =>
      await showDialog<bool>(
        context: pageContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('리뷰를 삭제할까요?'),
          content: const Text('삭제한 리뷰는 복구할 수 없습니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('삭제'),
            ),
          ],
        ),
      ) ??
      false;

  Future<bool> _deleteReview(Map<String, dynamic> review) async {
    try {
      await _request(
        'DELETE',
        '/review/${review['r_seq']}?email=${Uri.encodeQueryComponent(_email!)}',
      );
      _toast('리뷰를 삭제했습니다.');
      return true;
    } catch (error) {
      _toast('리뷰 삭제에 실패했습니다: $error');
      return false;
    }
  }

  Future<bool> _editReview(Map<String, dynamic> review) async {
    final postController = TextEditingController(
      text: '${review['post'] ?? ''}',
    );
    final fitController = TextEditingController(text: '${review['fit'] ?? ''}');
    var rating = ((review['rating'] as num?)?.toDouble() ?? 5)
        .clamp(1, 5)
        .toDouble();
    Uint8List? selectedImageBytes;
    String? selectedImageName;
    var saving = false;
    String? errorMessage;
    final picker = ImagePicker();

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, refreshSheet) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '리뷰 수정',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('${review['pr_name'] ?? review['SKU']}'),
                    Row(
                      children: [
                        const Text('평점'),
                        Expanded(
                          child: Slider(
                            value: rating,
                            min: 1,
                            max: 5,
                            divisions: 8,
                            label: rating.toStringAsFixed(1),
                            onChanged: (value) =>
                                refreshSheet(() => rating = value),
                          ),
                        ),
                        Text(rating.toStringAsFixed(1)),
                      ],
                    ),
                    TextField(
                      controller: fitController,
                      maxLength: 45,
                      decoration: const InputDecoration(labelText: '착용감'),
                    ),
                    TextField(
                      controller: postController,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 45,
                      onChanged: (_) => refreshSheet(() {}),
                      decoration: const InputDecoration(
                        labelText: '리뷰 내용',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          selectedImageBytes!,
                          height: 180,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (review['image_url'] is String)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          '${AppConfig.apiBaseUrl}/review/${review['r_seq']}/image',
                          height: 180,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: saving
                          ? null
                          : () async {
                              try {
                                final file = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                  maxWidth: 1600,
                                );
                                if (file == null) return;
                                final bytes = await file.readAsBytes();
                                refreshSheet(() {
                                  selectedImageBytes = bytes;
                                  selectedImageName = file.name;
                                  errorMessage = bytes.length > 5 * 1024 * 1024
                                      ? '사진은 5MB 이하로 선택해 주세요.'
                                      : null;
                                });
                              } catch (_) {
                                refreshSheet(() {
                                  errorMessage = '사진을 불러오지 못했습니다.';
                                });
                              }
                            },
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        selectedImageBytes == null ? '사진 추가 / 변경' : '사진 다시 선택',
                      ),
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed:
                          saving ||
                              postController.text.trim().isEmpty ||
                              (selectedImageBytes?.length ?? 0) >
                                  5 * 1024 * 1024
                          ? null
                          : () async {
                              refreshSheet(() {
                                saving = true;
                                errorMessage = null;
                              });
                              try {
                                await _sendReviewUpdate(
                                  review: review,
                                  post: postController.text.trim(),
                                  fit: fitController.text.trim(),
                                  rating: rating,
                                  imageBytes: selectedImageBytes,
                                  imageName: selectedImageName,
                                );
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext, true);
                                }
                              } catch (error) {
                                refreshSheet(() {
                                  saving = false;
                                  errorMessage = '저장 실패: $error';
                                });
                              }
                            },
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('변경 사항 저장'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      if (saved == true) _toast('리뷰를 수정했습니다.');
      return saved == true;
    } finally {
      postController.dispose();
      fitController.dispose();
    }
  }

  Future<void> _sendReviewUpdate({
    required Map<String, dynamic> review,
    required String post,
    required String fit,
    required double rating,
    required Uint8List? imageBytes,
    required String? imageName,
  }) async {
    final request =
        http.MultipartRequest(
            'PUT',
            Uri.parse('${AppConfig.apiBaseUrl}/review/${review['r_seq']}'),
          )
          ..fields.addAll({
            'email': _email!,
            'post': post,
            'fit': fit,
            'rating': rating.toStringAsFixed(1),
          });
    if (imageBytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: imageName ?? 'review.jpg',
        ),
      );
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw ApiRequestException(
        response.statusCode,
        detail?.toString() ?? '서버 요청 실패 (${response.statusCode})',
      );
    }
  }
}
