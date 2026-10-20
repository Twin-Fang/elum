import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/credit_repository.dart';

/// 크레딧 잔액 다시 받기: 다른 기능이 크레딧을 쓴 뒤 잔액 표시를 갱신
///
/// 다른 기능이 credit 의 data 를 직접 알지 않게 하는 입구 (tool/check_layer_imports.dart)
void refreshCreditSummary(Ref ref) => ref.invalidate(creditSummaryProvider);
