package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminRoutineList;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.Collection;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Mockito;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/** 일과 목록 조건 번역: 상태 필터, 허용 열 정렬, 검색 패턴, 페이지 보정, 쿼리 횟수 */
@ExtendWith(MockitoExtension.class)
class AdminRoutineServiceTest {

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private MemberRepository memberRepository;
  @InjectMocks private AdminRoutineService adminRoutineService;

  private record SearchCall(boolean hasKeyword, String pattern, Collection<RoutineStatus> statuses, Pageable pageable) {
  }

  private AdminListQuery query(String q, Map<String, String> filters, String sort, String page) {
    return AdminListQuery.of(q, filters, sort, page, AdminRoutineList.DEFINITION);
  }

  private SearchCall searchAndCapture(AdminListQuery query) {
    when(routineRepository.searchForAdmin(anyBoolean(), any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of()));
    adminRoutineService.search(query);
    ArgumentCaptor<Boolean> hasKeyword = ArgumentCaptor.forClass(Boolean.class);
    ArgumentCaptor<String> pattern = ArgumentCaptor.forClass(String.class);
    @SuppressWarnings("unchecked")
    ArgumentCaptor<Collection<RoutineStatus>> statuses = ArgumentCaptor.forClass(Collection.class);
    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(routineRepository).searchForAdmin(hasKeyword.capture(), pattern.capture(), statuses.capture(), pageable.capture());
    return new SearchCall(hasKeyword.getValue(), pattern.getValue(), statuses.getValue(), pageable.getValue());
  }

  private Routine routine(String id, String createdBy) {
    Profile profile = new Profile();
    profile.setNickname("하늘이");
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile);
    routine.setCreatedBy(createdBy);
    routine.setTitle("아침 준비");
    routine.setStatus(RoutineStatus.CONFIRMED);
    return routine;
  }

  @Test
  @DisplayName("상태 필터가 있으면 그 상태만, 없으면 모든 상태를 조회한다")
  void statusFilter_queriesThatStatusOnly_elseAll() {
    SearchCall filtered = searchAndCapture(query(null, Map.of("status", "COMPLETED"), null, null));
    assertThat(filtered.statuses()).containsExactly(RoutineStatus.COMPLETED);

    Mockito.clearInvocations(routineRepository);
    SearchCall all = searchAndCapture(query(null, Map.of(), null, null));
    assertThat(all.statuses()).containsExactlyInAnyOrder(RoutineStatus.values());
  }

  @Test
  @DisplayName("허용 밖 상태 값은 필터가 제거돼 전체 조회가 된다")
  void unknownStatus_isDropped() {
    SearchCall call = searchAndCapture(query(null, Map.of("status", "DELETED' or 1=1"), null, null));

    assertThat(call.statuses()).containsExactlyInAnyOrder(RoutineStatus.values());
  }

  @Test
  @DisplayName("정렬은 허용 열만 받고 허용 밖은 최근 변경순으로 돌아간다")
  void sort_allowedKeysOnlyElseDefault() {
    SearchCall byTitle = searchAndCapture(query(null, Map.of(), "title,asc", null));
    Sort.Order titleOrder = byTitle.pageable().getSort().getOrderFor("title");
    assertThat(titleOrder).isNotNull();
    assertThat(titleOrder.isAscending()).isTrue();

    Mockito.clearInvocations(routineRepository);
    SearchCall injected = searchAndCapture(query(null, Map.of(), "rawInputText,asc", null));
    Sort.Order defaultOrder = injected.pageable().getSort().getOrderFor("updatedAt");
    assertThat(defaultOrder).isNotNull();
    assertThat(defaultOrder.isDescending()).isTrue();
    assertThat(injected.pageable().getSort().getOrderFor("rawInputText")).isNull();
  }

  @Test
  @DisplayName("검색어의 LIKE 특수문자는 이스케이프되고 검색어가 없으면 조건을 건너뛴다")
  void keyword_escapesLikeSpecialCharacters() {
    SearchCall withKeyword = searchAndCapture(query("  하_늘%  ", Map.of(), null, null));
    assertThat(withKeyword.hasKeyword()).isTrue();
    assertThat(withKeyword.pattern()).isEqualTo("%하\\_늘\\%%");

    Mockito.clearInvocations(routineRepository);
    assertThat(searchAndCapture(query("   ", Map.of(), null, null)).hasKeyword()).isFalse();
  }

  @Test
  @DisplayName("범위 밖 페이지는 마지막 페이지로 맞춰 다시 조회한다")
  void pageBeyondLast_requeriesLastPage() {
    Page<Routine> empty = new PageImpl<>(List.of(), PageRequest.of(8, 20), 41);
    Page<Routine> last = new PageImpl<>(List.of(), PageRequest.of(2, 20), 41);
    when(routineRepository.searchForAdmin(anyBoolean(), any(), any(), any(Pageable.class))).thenReturn(empty, last);

    Page<AdminRoutineResponse> result = adminRoutineService.search(query(null, Map.of(), null, "9"));

    assertThat(result.getNumber()).isEqualTo(2);
    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(routineRepository, times(2)).searchForAdmin(anyBoolean(), any(), any(), pageable.capture());
    assertThat(pageable.getAllValues().get(1).getPageNumber()).isEqualTo(2);
  }

  @Test
  @DisplayName("보호자 계정명은 한 번에 묻고 일과에 회원 id 가 붙는다")
  void usernames_areLoadedOnce() {
    Member member = new Member();
    member.setId("m1");
    member.setUsername("parent1");
    when(routineRepository.searchForAdmin(anyBoolean(), any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(routine("r1", "m1"), routine("r2", "m1"), routine("r3", "gone"))));
    when(memberRepository.findAllById(any())).thenReturn(List.of(member));

    List<AdminRoutineResponse> content = adminRoutineService.search(query(null, Map.of(), null, null)).getContent();

    verify(memberRepository, times(1)).findAllById(any());
    assertThat(content).extracting(AdminRoutineResponse::memberUsername).containsExactly("parent1", "parent1", null);
    assertThat(content).extracting(AdminRoutineResponse::memberId).containsExactly("m1", "m1", "gone");
  }
}
