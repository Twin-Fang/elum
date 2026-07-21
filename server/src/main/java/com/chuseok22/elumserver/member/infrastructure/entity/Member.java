package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.CollectionTable;
import jakarta.persistence.Column;
import jakarta.persistence.ElementCollection;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import java.util.HashSet;
import java.util.Set;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Member extends BaseEntity {
  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false, unique = true)
  private String username;

  @Column(nullable = false)
  private String password;

  @Column(nullable = false, columnDefinition = "integer not null default 0")
  private Integer totalStars = 0;

  private String nickname;

  @Enumerated(EnumType.STRING)
  private CharacterType character;

  @ElementCollection(fetch = FetchType.EAGER)
  @CollectionTable(name = "member_support_goals", joinColumns = @JoinColumn(name = "member_id"))
  @Enumerated(EnumType.STRING)
  @Column(name = "support_goal", nullable = false)
  private Set<SupportGoal> supportGoals = new HashSet<>();
}
