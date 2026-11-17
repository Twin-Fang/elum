package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ActivitySection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.DraftRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.HistoryRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ProductRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.ProductsSection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.SaleSection;
import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPackView.StoreSale;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck.Finding;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPackHealthCheck.Snapshot;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseAdminQueryService;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigHistoryService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat;
import com.chuseok22.elumserver.systemconfig.core.CreditPackListFormat.Pack;
import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.function.Supplier;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 관리자 크레딧 > 꾸러미: 화면 조립(칸마다 독립 실패), 스토어별 판매 켜기·끄기, 상품 편집 검사·미리보기·저장
 * 저장은 기존 설정 키 5개와 SystemConfigService.update (값 검사, 사유, 변경 이력, 30초 안 전 서버 반영)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AdminCreditPackService {

  /// 화면 오류 코드 (제보 추적용)
  static final String REASON_CODE = "ADMIN-CREDIT-PACKS-REASON";
  static final String DRAFT_CODE = "ADMIN-CREDIT-PACKS-DRAFT";
  private static final String SECTION_CODE_PREFIX = "E-ADMIN-CREDIT-PACKS-";
  static final int REASON_MAX_LENGTH = 200;
  private static final int RECENT_DAYS = 7;
  private static final int HISTORY_LIMIT = 5;
  private static final String PRODUCT_DELIMITER = ",";
  private static final String PRODUCT_VALUE_DELIMITER = ":";

  /// 꾸러미 설정 키 5개: 이력 칸이 이 키들의 변경만 모아 보여 줌
  private static final List<ConfigKey> PACK_KEYS = List.of(
    ConfigKey.CREDIT_PACK_SALE_ENABLED, ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED, ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED,
    ConfigKey.CREDIT_PACK_PRODUCTS, ConfigKey.CREDIT_PACK_POPULAR_PRODUCT_ID);

  private final SystemConfigService config;
  private final SystemConfigHistoryService historyService;
  private final CreditPurchaseAdminQueryService purchaseQuery;

  /// 입력 검사 결과: 통과 여부, 관리자에게 보일 문구, 미리보기 줄(통과일 때만)
  public record DraftCheck(boolean isValid, String message, String productsText, List<ProductRow> previewRows) {

    static DraftCheck rejected(String message) {
      return new DraftCheck(false, message, null, List.of());
    }

    /// 컨트롤러가 저장 중 예외를 거절 결과로 바꿀 때
    public static DraftCheck rejectedWith(String message) {
      return rejected(message);
    }
  }

  /// 판매 켜기·끄기 결과 문구
  public record SaleChange(boolean isChanged, String message) {

  }

  /// 화면 전체: 칸마다 따로 읽고, 실패한 칸은 null + 코드
  public AdminCreditPackView view() {
    List<String> failedCodes = new ArrayList<>();
    SaleSection sale = guard("SALE", failedCodes, this::saleSection);
    ProductsSection products = guard("PRODUCTS", failedCodes, this::productsSection);
    List<Finding> findings = guard("CHECK", failedCodes, this::findings);
    ActivitySection activity = guard("ACTIVITY", failedCodes, this::activitySection);
    List<HistoryRow> histories = guard("HISTORY", failedCodes, this::historyRows);
    return new AdminCreditPackView(sale, products, findings, activity, histories, failedCodes);
  }

  /// 스토어 스위치 하나 켜기·끄기: 사유 검사 > 설정 저장(이력에 관리자·사유)
  public SaleChange setStoreSale(SubscriptionSource store, boolean isEnabled, String actor, String reason) {
    String reasonProblem = reasonProblemOf(reason);
    if (reasonProblem != null) {
      return new SaleChange(false, reasonProblem);
    }
    ConfigKey key = switchKeyOf(store);
    if (key == null) {
      return new SaleChange(false, "판매를 바꿀 수 없는 스토어예요 (" + DRAFT_CODE + ")");
    }
    try {
      config.update(key, String.valueOf(isEnabled), actor, reason.trim());
    } catch (CustomException e) {
      log.warn("[credit pack admin] sale switch rejected : key={}, {}", key, e.getErrorCode());
      return new SaleChange(false, "저장하지 못했어요: " + detailOf(e));
    }
    log.info("[credit pack admin] sale switch changed : store={}, enabled={}, actor={}", store, isEnabled, actor);
    return new SaleChange(true, store.getLabel() + " 판매를 " + (isEnabled ? "켰어요" : "껐어요. 이미 산 크레딧은 그대로 쓸 수 있어요"));
  }

  /// 편집 입력 검사 + 미리보기 (저장 안 함): 빈 칸 > 형식·중복·범위 > 인기 상품이 목록에 있는지
  public DraftCheck checkDraft(List<DraftRow> draftRows, String popularProductId) {
    String productsText = serialize(draftRows);
    if (productsText == null) {
      return DraftCheck.rejected("상품 ID 와 크레딧 개수를 둘 다 채워 주세요 (" + DRAFT_CODE + ")");
    }
    String formatProblem = CreditPackListFormat.invalidReason(productsText);
    if (formatProblem != null) {
      return DraftCheck.rejected(formatProblem + " (" + DRAFT_CODE + ")");
    }
    String normalizedText = CreditPackListFormat.normalize(productsText);
    List<Pack> packs = CreditPackListFormat.parse(normalizedText);
    String popular = popularProductId == null ? "" : popularProductId.trim();
    if (!popular.isEmpty() && packs.stream().noneMatch(pack -> pack.productId().equals(popular))) {
      return DraftCheck.rejected("인기 상품은 목록에 있는 상품 중에서 골라 주세요 (" + DRAFT_CODE + ")");
    }
    List<ProductRow> previewRows = packs.stream()
      .map(pack -> new ProductRow(pack.productId(), pack.credits(), pack.productId().equals(popular)))
      .toList();
    return new DraftCheck(true, "미리보기예요. 저장하면 앱에 이렇게 반영돼요", normalizedText, previewRows);
  }

  /// 상품 목록과 인기 상품을 함께 저장 (같은 트랜잭션: 둘 다 바뀌거나 둘 다 안 바뀜)
  @Transactional
  public DraftCheck saveDraft(List<DraftRow> draftRows, String popularProductId, String actor, String reason) {
    String reasonProblem = reasonProblemOf(reason);
    if (reasonProblem != null) {
      return DraftCheck.rejected(reasonProblem);
    }
    DraftCheck check = checkDraft(draftRows, popularProductId);
    if (!check.isValid()) {
      return check;
    }
    String popular = popularProductId == null ? "" : popularProductId.trim();
    try {
      config.update(ConfigKey.CREDIT_PACK_PRODUCTS, check.productsText(), actor, reason.trim());
      config.update(ConfigKey.CREDIT_PACK_POPULAR_PRODUCT_ID, popular, actor, reason.trim());
    } catch (CustomException e) {
      log.warn("[credit pack admin] products rejected : {}", e.getErrorCode());
      throw e;
    }
    log.info("[credit pack admin] products saved : count={}, popular={}, actor={}", check.previewRows().size(), popular, actor);
    return new DraftCheck(true, "꾸러미 상품을 저장했어요", check.productsText(), check.previewRows());
  }

  /// 입력 줄 > "상품ID:개수" 쉼표 문자열 (둘 다 빈 줄은 건너뜀, 하나만 빈 줄이 있으면 null)
  static String serialize(List<DraftRow> draftRows) {
    List<String> items = new ArrayList<>();
    for (DraftRow row : draftRows) {
      String productId = row.productId() == null ? "" : row.productId().trim();
      String credits = row.credits() == null ? "" : row.credits().trim();
      if (productId.isEmpty() && credits.isEmpty()) {
        continue;
      }
      if (productId.isEmpty() || credits.isEmpty()) {
        return null;
      }
      items.add(productId + PRODUCT_VALUE_DELIMITER + credits);
    }
    return String.join(PRODUCT_DELIMITER, items);
  }

  private SaleSection saleSection() {
    List<StoreSale> stores = List.of(
      new StoreSale(SubscriptionSource.APPLE_IAP, SubscriptionSource.APPLE_IAP.getLabel(), config.getBoolean(ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED)),
      new StoreSale(SubscriptionSource.GOOGLE_IAP, SubscriptionSource.GOOGLE_IAP.getLabel(), config.getBoolean(ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED)));
    return new SaleSection(config.getBoolean(ConfigKey.CREDIT_PACK_SALE_ENABLED), stores);
  }

  private ProductsSection productsSection() {
    String popular = config.getString(ConfigKey.CREDIT_PACK_POPULAR_PRODUCT_ID).trim();
    List<ProductRow> rows = CreditPackListFormat.parse(config.getString(ConfigKey.CREDIT_PACK_PRODUCTS)).stream()
      .map(pack -> new ProductRow(pack.productId(), pack.credits(), pack.productId().equals(popular)))
      .toList();
    return new ProductsSection(rows, popular);
  }

  private List<Finding> findings() {
    return CreditPackHealthCheck.check(new Snapshot(
      config.getBoolean(ConfigKey.CREDIT_PACK_SALE_ENABLED),
      config.getBoolean(ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED),
      config.getBoolean(ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED),
      config.getString(ConfigKey.CREDIT_PACK_PRODUCTS),
      config.getString(ConfigKey.CREDIT_PACK_POPULAR_PRODUCT_ID),
      config.getBoolean(ConfigKey.STORE_REFUND_RECHECK_ENABLED)));
  }

  private ActivitySection activitySection() {
    LocalDateTime since = LocalDateTime.now().minusDays(RECENT_DAYS);
    return new ActivitySection(purchaseQuery.countCreatedSince(since), purchaseQuery.countRefundedSince(since));
  }

  /// 꾸러미 설정 5개의 변경 이력 > 최신순 5건
  private List<HistoryRow> historyRows() {
    List<SystemConfigHistory> merged = new ArrayList<>();
    for (ConfigKey key : PACK_KEYS) {
      merged.addAll(historyService.recentOf(key.name()).stream().limit(HISTORY_LIMIT).toList());
    }
    return merged.stream()
      .sorted(Comparator.comparing(SystemConfigHistory::getCreatedAt).reversed())
      .limit(HISTORY_LIMIT)
      .map(history -> new HistoryRow(keyLabelOf(history.getConfigKey()), history.getOldValue(), history.getNewValue(),
        history.getChangedBy(), history.getReason(), history.getCreatedAt()))
      .toList();
  }

  private static String keyLabelOf(String configKey) {
    for (ConfigKey key : PACK_KEYS) {
      if (key.name().equals(configKey)) {
        return key.getLabel();
      }
    }
    return configKey;
  }

  private static ConfigKey switchKeyOf(SubscriptionSource store) {
    return switch (store) {
      case APPLE_IAP -> ConfigKey.CREDIT_PACK_APPLE_SALE_ENABLED;
      case GOOGLE_IAP -> ConfigKey.CREDIT_PACK_GOOGLE_SALE_ENABLED;
      default -> null;
    };
  }

  /// 사유가 없거나 길면 이유 문구, 괜찮으면 null
  private static String reasonProblemOf(String reason) {
    if (reason == null || reason.isBlank() || reason.trim().length() > REASON_MAX_LENGTH) {
      return "사유를 " + REASON_MAX_LENGTH + "자 안으로 적어 주세요 (" + REASON_CODE + ")";
    }
    return null;
  }

  private static String detailOf(CustomException e) {
    return e.getDetail() == null || e.getDetail().isBlank() ? "값이 올바르지 않아요 (E-CFG-001)" : e.getDetail() + " (E-CFG-001)";
  }

  /// 칸 하나 읽기: 실패하면 null 을 주고 코드만 남김 (다른 칸은 그대로 그려짐)
  private <T> T guard(String sectionName, List<String> failedCodes, Supplier<T> reader) {
    try {
      return reader.get();
    } catch (RuntimeException e) {
      log.warn("[credit pack admin] section failed : section={}, cause={}", sectionName, e.getClass().getSimpleName());
      failedCodes.add(SECTION_CODE_PREFIX + sectionName);
      return null;
    }
  }
}
