%---------------------------------------------------------------------------%
% vim: ft=mercury ts=4 sw=4 et
%---------------------------------------------------------------------------%
% Copyright (C) 2009-2012 The University of Melbourne.
% Copyright (C) 2015,2017-2024 The Mercury team.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%---------------------------------------------------------------------------%
%
% File: modecheck_util.m.
%
%---------------------------------------------------------------------------%

:- module check_hlds.modecheck_util.
:- interface.

:- import_module check_hlds.mode_errors.
:- import_module check_hlds.mode_info.
:- import_module hlds.
:- import_module hlds.hlds_goal.
:- import_module hlds.hlds_module.
:- import_module hlds.hlds_pred.
:- import_module hlds.instmap.
:- import_module parse_tree.
:- import_module parse_tree.prog_data.

:- import_module list.
:- import_module maybe.
:- import_module set.

%---------------------------------------------------------------------------%

:- type extra_goals
    --->    no_extra_goals
    ;       extra_goals(
                % Goals to insert before the main goal.
                extra_before_main   :: list(hlds_goal),

                % Goals to append after the main goal.
                extra_after_main    :: list(hlds_goal)
            ).

:- type after_goals
    --->    no_after_goals
    ;       after_goals(
                % Instmap at end of main goal.
                after_instmap       :: instmap,

                % Goals to append after the main goal.
                after_goals         :: list(hlds_goal)
            ).

    % Append_extra_goals inserts adds some goals to the
    % list of goals to insert before/after the main goal.
    %
:- pred append_extra_goals(extra_goals::in, extra_goals::in,
    extra_goals::out) is det.

    % Handle_extra_goals combines MainGoal and ExtraGoals into a single
    % hlds_goal_expr, rerunning mode analysis on the entire conjunction
    % if ExtraGoals is not empty.
    %
:- pred handle_extra_goals(hlds_goal_expr::in, extra_goals::in,
    hlds_goal_info::in, list(prog_var)::in, list(prog_var)::in,
    instmap::in, hlds_goal_expr::out, mode_info::in, mode_info::out) is det.

%---------------------------------------------------------------------------%

    % Create a unification between the two given variables.
    % The goal's mode and determinism information are not filled in.
    %
:- pred create_var_var_unification(prog_var::in, prog_var::in,
    mer_type::in, mode_info::in, hlds_goal::out) is det.

%---------------------------------------------------------------------------%

    % The polymophism pass can add type_info and/or typeclass_info arguments
    % to predicates' argument vectors before arguments visible to users.
    % Since it would be confusing to refer to e.g. the second user-visible
    % argument as "argument 5" in a diagnostic message just because
    % polymophism added three arguments, we need a way to get references
    % to argument numbers right.
    %
    % Values of this type, computed by one of the three functions below,
    % specify the offset we need to apply to get from actual positions
    % in the argument vector on the one hand to the argument numbers
    % we should use in diagnostics on the other hand. The actual definition
    % of this type, which is not exported, is a wrapper around an integer
    % which is -N if a predicate has N compiler-generated arguments.
    %
    % The predicates that use values of this type all iterate on all the
    % arguments in an argument vector. They all increment the number inside
    % the wrapper as they go, and they do so *before* processing an argument.
    % This way, if a predicate has (say) three compiler-generated arguments,
    % then compute_pred_modecheck_arg_offset will return a wrapper around -3,
    % the compiler-generated arguments will be processed with their argument
    % numbers being -2, -1 and 0, and the user-visible arguments will have
    % their numbers start at 1, as intended.
    %
    % The intention is that diagnostics simply omit from their text any
    % argument numbers that are negative or zero.
    %
:- type modecheck_arg_offset.

:- func compute_pred_modecheck_arg_offset(pred_info) = modecheck_arg_offset.
:- func higher_order_modecheck_arg_offset = modecheck_arg_offset.
:- func unify_method_event_cast_modecheck_arg_offset = modecheck_arg_offset.

%---------------------------------------------------------------------------%

    % Given a list of variables and a list of expected liveness, ensure
    % that the inst of each variable satisfies the corresponding expected
    % liveness. See below for the difference between the two variants.
    %
:- pred modecheck_vars_are_live_exact_match(modecheck_arg_offset::in,
    list(prog_var)::in, list(is_live)::in,
    mode_info::in, mode_info::out) is det.
:- pred modecheck_vars_are_live_no_exact_match(modecheck_arg_offset::in,
    list(prog_var)::in, list(is_live)::in,
    mode_info::in, mode_info::out) is det.

    % Given a list of variables and a list of initial insts, ensure that
    % the inst of each variable matches the corresponding initial inst.
    % The first variant requires an exact match (using inst_matches_final),
    % while the second we allow the var to be more instantiated than the inst
    % (using inst_matches_initial).
    %
:- pred modecheck_vars_have_insts_exact_match(match_what::in,
    modecheck_arg_offset::in, list(prog_var)::in, list(mer_inst)::in,
    inst_var_sub::out, set(inst_var)::out,
    mode_info::in, mode_info::out) is det.
:- pred modecheck_vars_have_insts_no_exact_match(match_what::in,
    modecheck_arg_offset::in, list(prog_var)::in, list(mer_inst)::in,
    inst_var_sub::out, set(inst_var)::out,
    mode_info::in, mode_info::out) is det.

    % This is a special-cased, cut-down version of
    % modecheck_vars_have_insts_no_exact_match for use specifically
    % on introduced type_info_type variables.
    %
:- pred modecheck_introduced_type_info_var_has_inst_no_exact_match(
    prog_var::in, mer_type::in, mer_inst::in,
    mode_info::in, mode_info::out) is det.

%---------------------------------------------------------------------------%

:- pred get_var_inst(mode_info::in, prog_var::in, mer_inst::out) is det.

    % modecheck_set_var_inst(Var, Inst, MaybeUInst, !ModeInfo):
    %
    % Assign the given Inst to the given Var, after checking that it is
    % okay to do so. If the inst to be assigned is the result of an
    % abstract unification, then the MaybeUInst argument should be the
    % initial inst of the _other_ side of the unification. This allows
    % more precise (i.e. less conservative) checking in the case that
    % Inst contains `any' components and Var is locked (i.e. is a
    % nonlocal variable in a negated context). Where the inst is not
    % the result of an abstract unification then MaybeUInst should be `no'.
    %
:- pred modecheck_set_var_inst(prog_var::in, mer_inst::in, maybe(mer_inst)::in,
    mode_info::in, mode_info::out) is det.

:- pred modecheck_set_var_insts(modecheck_arg_offset::in, list(prog_var)::in,
    list(mer_inst)::in, list(mer_inst)::in,
    list(prog_var)::out, extra_goals::out,
    mode_info::in, mode_info::out) is det.

%---------------------------------------------------------------------------%

:- pred mode_info_add_goals_live_vars(conj_type::in, list(hlds_goal)::in,
    mode_info::in, mode_info::out) is det.

:- pred mode_info_remove_goals_live_vars(list(hlds_goal)::in,
    mode_info::in, mode_info::out) is det.

%---------------------------------------------------------------------------%

    % modecheck_functor_test(Var, ConsId, !ModeInfo):
    %
    % Update the instmap to reflect the fact that Var was bound to ConsId.
    % This is used for the functor tests in `switch' statements.
    %
:- pred modecheck_record_functor_test(prog_var::in, cons_id::in,
    mode_info::in, mode_info::out) is det.

    % modecheck_functors_test(Var, MainConsId, OtherConsIds, !ModeInfo):
    %
    % Update the instmap to reflect the fact that Var was bound to either
    % MainConsId or one of the OtherConsIds.
    % This is used for the functor tests in `switch' statements.
    %
:- pred modecheck_record_functors_test(prog_var::in, cons_id::in,
    list(cons_id)::in, mode_info::in, mode_info::out) is det.

%---------------------------------------------------------------------------%

    % compute_goal_instmap_delta(InstMap0, GoalExpr, !GoalInfo, !ModeInfo):
    %
    % Work out the instmap_delta for a goal from the instmaps before and after
    % the goal. The instmap before the goal is given by InstMap0; the instmap
    % after the goal is given by !.ModeInfo.
    %
:- pred compute_goal_instmap_delta(instmap::in, hlds_goal_expr::in,
    hlds_goal_info::in, hlds_goal_info::out, mode_info::in, mode_info::out)
    is det.

%---------------------------------------------------------------------------%

:- pred mode_context_to_unify_context(mode_info::in, mode_context::in,
    unify_context::out) is det.

:- func mode_call_id_to_call_id(mode_info, mode_call_id) = call_id.

%---------------------------------------------------------------------------%

    % Given a list of variables, and a list of livenesses,
    % select the live variables.
    %
:- pred get_live_vars(list(prog_var)::in, list(is_live)::in,
    list(prog_var)::out) is det.

%---------------------------------------------------------------------------%

    % Return a map of all the inst variables in the given modes, and the
    % sub-insts to which they are constrained.
    %
:- pred get_constrained_inst_vars(module_info::in, list(mer_mode)::in,
    head_inst_vars::out) is det.

%---------------------------------------------------------------------------%

    % Given the switched-on variable and the instmaps
    % - before the switch, and
    % - after a branch,
    % make sure that any information added by the functor test gets added
    % to the instmap for the case.
    %
:- pred fixup_instmap_switch_var(prog_var::in, instmap::in, instmap::in,
    hlds_goal::in, hlds_goal::out) is det.

%---------------------------------------------------------------------------%

:- pred normalise_inst(module_info::in, mer_type::in,
    mer_inst::in, mer_inst::out) is det.
:- pred normalise_insts(module_info::in, list(mer_type)::in,
    list(mer_inst)::in, list(mer_inst)::out) is det.

%---------------------------------------------------------------------------%

:- pred propagate_type_ho_inst_info_into_inst(mer_type::in,
    mer_inst::in, mer_inst::out) is det.

%---------------------------------------------------------------------------%
%---------------------------------------------------------------------------%

:- implementation.

:- import_module check_hlds.delay_info.
:- import_module check_hlds.inst_abstract_unify.
:- import_module check_hlds.inst_lookup.
:- import_module check_hlds.inst_match.
:- import_module check_hlds.inst_test.
:- import_module check_hlds.mode_util.
:- import_module check_hlds.modecheck_goal.
:- import_module check_hlds.polymorphism_goal.
:- import_module check_hlds.type_util.
:- import_module hlds.make_goal.
:- import_module parse_tree.prog_mode.
:- import_module parse_tree.prog_type.
:- import_module parse_tree.prog_util.
:- import_module parse_tree.set_of_var.
:- import_module parse_tree.var_db.
:- import_module parse_tree.var_table.

:- import_module bool.
:- import_module int.
:- import_module map.
:- import_module require.
:- import_module set_tree234.
:- import_module term.

%---------------------------------------------------------------------------%

append_extra_goals(no_extra_goals, ExtraGoals, ExtraGoals).
append_extra_goals(extra_goals(BeforeGoals, AfterGoals),
        no_extra_goals, extra_goals(BeforeGoals, AfterGoals)).
append_extra_goals(extra_goals(BeforeGoals0, AfterGoals0),
        extra_goals(BeforeGoals1, AfterGoals1),
        extra_goals(BeforeGoals, AfterGoals)) :-
    BeforeGoals = BeforeGoals0 ++ BeforeGoals1,
    AfterGoals = AfterGoals0 ++ AfterGoals1.

%---------------------%

handle_extra_goals(MainGoal, no_extra_goals, _GoalInfo0, _Args0, _Args,
        _InstMap0, MainGoal, !ModeInfo).
handle_extra_goals(MainGoal, extra_goals(BeforeGoals0, AfterGoals0),
        GoalInfo0, Args0, Args, InstMap0, Goal, !ModeInfo) :-
    mode_info_get_errors(!.ModeInfo, Errors),
    ( if
        % There is no point adding extra goals if the code is unreachable
        % anyway.
        instmap_is_reachable(InstMap0),

        % If we recorded errors processing the goal, it will have to be
        % reprocessed anyway, so don't add the extra goals now.
        Errors = []
    then
        % We need to be careful to update the delta-instmaps
        % correctly, using the appropriate instmaps:
        %
        %       % InstMapAtStart is here
        %    BeforeGoals,
        %       % we don't know the instmap here,
        %       % but as it happens we don't need it
        %    main goal,
        %       % InstMapAfterMain is here
        %    AfterGoals
        %       % InstMapAtEnd (from the ModeInfo) is here

        % Recompute the new set of non-local variables for the main goal.
        NonLocals0 = goal_info_get_nonlocals(GoalInfo0),
        set_of_var.list_to_set(Args0, OldArgVars),
        set_of_var.list_to_set(Args, NewArgVars),
        set_of_var.difference(NewArgVars, OldArgVars, IntroducedVars),
        set_of_var.union(NonLocals0, IntroducedVars, OutsideVars),
        set_of_var.intersect(OutsideVars, NewArgVars, NonLocals),
        goal_info_set_nonlocals(NonLocals, GoalInfo0, GoalInfo),

        % Combine the main goal and the extra goals into a conjunction.
        Goal0 = hlds_goal(MainGoal, GoalInfo),
        Context = goal_info_get_context(GoalInfo0),
        handle_extra_goals_contexts(BeforeGoals0, Context, BeforeGoals),
        handle_extra_goals_contexts(AfterGoals0, Context, AfterGoals),
        GoalList0 = BeforeGoals ++ [Goal0 | AfterGoals],

        mode_info_get_may_change_called_proc(!.ModeInfo, MayChangeCalledProc0),

        % Make sure we don't go into an infinite loop if
        % there is a bug in the code to add extra goals.
        mode_info_set_checking_extra_goals(yes, !ModeInfo),

        % We have already worked out which procedure should be called,
        % we don't need to do it again.
        mode_info_set_may_change_called_proc(may_not_change_called_proc,
            !ModeInfo),

        mode_info_set_instmap(InstMap0, !ModeInfo),

        % Recheck the goals to compute the instmap_deltas.
        %
        % This can fail even if the original check on the goal
        % succeeded in the case of a unification procedure which
        % binds a partially instantiated variable, because adding
        % the extra goals can make the partially instantiated
        % variables `live' after the main goal.
        % The other thing to beware of in this case is that delaying
        % must be disabled while processing the extra goals. If it
        % is not, the main unification will be delayed until after the
        % argument unifications, which turns them into assignments,
        % and we end up repeating the process forever.
        mode_info_add_goals_live_vars(plain_conj, GoalList0, !ModeInfo),
        modecheck_conj_list_no_delay(GoalList0, GoalList, !ModeInfo),
        Goal = conj(plain_conj, GoalList),
        mode_info_set_checking_extra_goals(no, !ModeInfo),
        mode_info_set_may_change_called_proc(MayChangeCalledProc0, !ModeInfo)
    else
        Goal = MainGoal
    ).

    % Modecheck a conjunction without doing any reordering.
    % This is used by handle_extra_goals above.
    %
:- pred modecheck_conj_list_no_delay(list(hlds_goal)::in, list(hlds_goal)::out,
    mode_info::in, mode_info::out) is det.

modecheck_conj_list_no_delay([], [], !ModeInfo).
modecheck_conj_list_no_delay([Goal0 | Goals0], [Goal | Goals], !ModeInfo) :-
    NonLocals = goal_get_nonlocals(Goal0),
    mode_info_remove_live_vars(NonLocals, !ModeInfo),
    modecheck_goal(Goal0, Goal, !ModeInfo),
    mode_info_get_instmap(!.ModeInfo, InstMap),
    ( if instmap_is_unreachable(InstMap) then
        % We should not mode-analyse the remaining goals, since they
        % are unreachable. Instead we optimize them away, so that
        % later passes won't complain about them not having mode information.
        mode_info_remove_goals_live_vars(Goals0, !ModeInfo),
        Goals  = []
    else
        modecheck_conj_list_no_delay(Goals0, Goals, !ModeInfo)
    ).

:- pred handle_extra_goals_contexts(list(hlds_goal)::in, prog_context::in,
    list(hlds_goal)::out) is det.

handle_extra_goals_contexts([], _Context, []).
handle_extra_goals_contexts([Goal0 | Goals0], Context, [Goal | Goals]) :-
    Goal0 = hlds_goal(GoalExpr, GoalInfo0),
    goal_info_set_context(Context, GoalInfo0, GoalInfo),
    Goal = hlds_goal(GoalExpr, GoalInfo),
    handle_extra_goals_contexts(Goals0, Context, Goals).

%---------------------------------------------------------------------------%

create_var_var_unification(Var0, Var, Type, ModeInfo, Goal) :-
    Goal = hlds_goal(GoalExpr, GoalInfo),
    mode_info_get_context(ModeInfo, Context),
    mode_info_get_mode_context(ModeInfo, ModeContext),
    mode_context_to_unify_context(ModeInfo, ModeContext, UnifyContext),
    UnifyContext = unify_context(MainContext, SubContexts),

    create_pure_atomic_complicated_unification(Var0, rhs_var(Var), Context,
        MainContext, SubContexts, hlds_goal(GoalExpr0, GoalInfo0)),

    % Compute the goal_info nonlocal vars for the newly created goal
    % (excluding the type_info vars -- they are added below).
    % N.B. This may overestimate the set of non-locals,
    % but that shouldn't cause any problems.

    set_of_var.list_to_set([Var0, Var], NonLocals),
    goal_info_set_nonlocals(NonLocals, GoalInfo0, GoalInfo1),
    goal_info_set_context(Context, GoalInfo1, GoalInfo2),

    % Look up the map(tvar, type_info_locn) in the proc_info,
    % since it is needed by polymorphism.unification_typeinfos.

    mode_info_get_module_info(ModeInfo, ModuleInfo),
    mode_info_get_pred_id(ModeInfo, PredId),
    mode_info_get_proc_id(ModeInfo, ProcId),
    module_info_pred_proc_info(ModuleInfo, PredId, ProcId,
        _PredInfo, ProcInfo),
    proc_info_get_rtti_varmaps(ProcInfo, RttiVarMaps),

    % Call polymorphism.unification_typeinfos to add the appropriate
    % type-info and type-class-info variables to the nonlocals
    % and to the unification.

    ( if GoalExpr0 = unify(X, Y, Mode, Unification0, FinalUnifyContext) then
        unification_typeinfos_rtti_varmaps(Type, RttiVarMaps,
            Unification0, Unification, GoalInfo2, GoalInfo),
        GoalExpr = unify(X, Y, Mode, Unification, FinalUnifyContext)
    else
        unexpected($pred, "unexpected GoalExpr0")
    ).

%---------------------------------------------------------------------------%

:- type modecheck_arg_offset
    --->    modecheck_arg_offset(int).

compute_pred_modecheck_arg_offset(PredInfo) = ArgOffset :-
    pred_info_get_orig_arity(PredInfo, pred_form_arity(PredFormArityInt)),
    pred_info_get_arg_types(PredInfo, ArgTypes),
    % Note that this is not num_extra_args; it does the subtraction
    % in the *other* direction.
    list.length(ArgTypes, CurrentArity),
    ArgOffset = modecheck_arg_offset(PredFormArityInt - CurrentArity).

higher_order_modecheck_arg_offset = modecheck_arg_offset(1).
    % This return value makes the initial argument "argument 2".
    % This is because the first implementation of higher order calls
    % used the "call(P, A, B, C)" syntax Mercury inherited from Prolog;
    % both the P(A, B, C) syntax, and functions themselves, came later.
    % And when checking the types or modes of higher order calls,
    % we check the types/modes of A, B and C *against* the type/mode info
    % we have in P; we treat P as the source of what is expected, not as
    % something to be *compared* to the expected.
    %
    % The arg_number_to_string function in hlds_out_util.m deduct 1
    % from argument numbers for calls that use P(A, B, C) syntax, while
    % leaving argument numbers unchanged for calls using call(P, A, B, C)
    % syntax.

unify_method_event_cast_modecheck_arg_offset = modecheck_arg_offset(0).

%---------------------------------------------------------------------------%

modecheck_vars_are_live_exact_match(_, [], [], !ModeInfo).
modecheck_vars_are_live_exact_match(_, [_ | _], [], !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_are_live_exact_match(_, [], [_ | _], !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_are_live_exact_match(ArgOffset0,
        [Var | Vars], [IsLive | IsLives], !ModeInfo) :-
    ArgOffset0 = modecheck_arg_offset(ArgNum0),
    ArgNum = ArgNum0 + 1,
    ArgOffset = modecheck_arg_offset(ArgNum),
    mode_info_set_call_arg_context(ArgNum, !ModeInfo),
    modecheck_var_is_live_exact_match(Var, IsLive, !ModeInfo),
    modecheck_vars_are_live_exact_match(ArgOffset, Vars, IsLives, !ModeInfo).

modecheck_vars_are_live_no_exact_match(_, [], [], !ModeInfo).
modecheck_vars_are_live_no_exact_match(_, [_ | _], [], !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_are_live_no_exact_match(_, [], [_ | _], !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_are_live_no_exact_match(ArgOffset0,
        [Var | Vars], [IsLive | IsLives], !ModeInfo) :-
    ArgOffset0 = modecheck_arg_offset(ArgNum0),
    ArgNum = ArgNum0 + 1,
    ArgOffset = modecheck_arg_offset(ArgNum),
    mode_info_set_call_arg_context(ArgNum, !ModeInfo),
    modecheck_var_is_live_no_exact_match(Var, IsLive, !ModeInfo),
    modecheck_vars_are_live_no_exact_match(ArgOffset, Vars, IsLives,
        !ModeInfo).

%---------------------%
%
% `live' means possibly used later on, and `dead' means definitely not used
% later on. If you don't need an exact match, then the only time you get
% an error is if you pass a variable which is live to a predicate
% that expects the variable to be dead; the predicate may use destructive
% update to clobber the variable, so we must be sure that it is dead
% after the call.
%

    % A version of modecheck_var_is_live specialized for NeedExactMatch = no.
    %
:- pred modecheck_var_is_live_no_exact_match(prog_var::in, is_live::in,
    mode_info::in, mode_info::out) is det.

modecheck_var_is_live_no_exact_match(Var, ExpectedIsLive, !ModeInfo) :-
    mode_info_var_is_live(!.ModeInfo, Var, VarIsLive),
    ( if
        ExpectedIsLive = is_dead,
        VarIsLive = is_live
    then
        WaitingVars = set_of_var.make_singleton(Var),
        ModeError = mode_error_clobbered_var_is_live(Var),
        mode_info_error(WaitingVars, ModeError, !ModeInfo)
    else
        true
    ).

    % A version of modecheck_var_is_live specialized for NeedExactMatch = yes.
    %
:- pred modecheck_var_is_live_exact_match(prog_var::in, is_live::in,
    mode_info::in, mode_info::out) is det.

modecheck_var_is_live_exact_match(Var, ExpectedIsLive, !ModeInfo) :-
    mode_info_var_is_live(!.ModeInfo, Var, VarIsLive),
    ( if VarIsLive = ExpectedIsLive then
        true
    else
        WaitingVars = set_of_var.make_singleton(Var),
        ModeError = mode_error_clobbered_var_is_live(Var),
        mode_info_error(WaitingVars, ModeError, !ModeInfo)
    ).

%---------------------------------------------------------------------------%

modecheck_vars_have_insts_exact_match(MatchWhat, ArgOffset,
        Vars, ReqInitialInsts, Subst, BoundInstVars, !ModeInfo) :-
    ArgOffset = modecheck_arg_offset(ArgNum),
    modecheck_vars_have_insts_exact_match_loop(Vars, ReqInitialInsts,
        ArgNum, map.init, Subst, !ModeInfo),
    modecheck_find_bound_head_inst_vars(MatchWhat, eon_exact, Vars,
        ReqInitialInsts, Subst, BoundInstVars, !ModeInfo).

modecheck_vars_have_insts_no_exact_match(MatchWhat, ArgOffset,
        Vars, ReqInitialInsts, Subst, BoundInstVars, !ModeInfo) :-
    ArgOffset = modecheck_arg_offset(ArgNum),
    modecheck_vars_have_insts_no_exact_match_loop(Vars, ReqInitialInsts,
        ArgNum, map.init, Subst, !ModeInfo),
    modecheck_find_bound_head_inst_vars(MatchWhat, eon_not_exact, Vars,
        ReqInitialInsts, Subst, BoundInstVars, !ModeInfo).

%---------------------%

:- pred modecheck_vars_have_insts_exact_match_loop(list(prog_var)::in,
    list(mer_inst)::in, int::in, inst_var_sub::in, inst_var_sub::out,
    mode_info::in, mode_info::out) is det.

modecheck_vars_have_insts_exact_match_loop([], [],
        _, !Subst, !ModeInfo).
modecheck_vars_have_insts_exact_match_loop([_ | _], [],
        _, !Subst, !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_have_insts_exact_match_loop([], [_ | _],
        _, !Subst, !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_have_insts_exact_match_loop([Var | Vars],
        [ReqInitialInst | ReqInitialInsts], ArgNum0, !Subst, !ModeInfo) :-
    ArgNum = ArgNum0 + 1,
    mode_info_set_call_arg_context(ArgNum, !ModeInfo),
    modecheck_var_has_inst_exact_match(Var, ReqInitialInst, !Subst, !ModeInfo),
    modecheck_vars_have_insts_exact_match_loop(Vars, ReqInitialInsts,
        ArgNum, !Subst, !ModeInfo).

:- pred modecheck_vars_have_insts_no_exact_match_loop(list(prog_var)::in,
    list(mer_inst)::in, int::in, inst_var_sub::in, inst_var_sub::out,
    mode_info::in, mode_info::out) is det.

modecheck_vars_have_insts_no_exact_match_loop([], [],
        _, !Subst, !ModeInfo).
modecheck_vars_have_insts_no_exact_match_loop([_ | _], [],
        _, !Subst, !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_have_insts_no_exact_match_loop([], [_ | _],
        _, !Subst, !ModeInfo) :-
    unexpected($pred, "length mismatch").
modecheck_vars_have_insts_no_exact_match_loop([Var | Vars],
        [ReqInitialInst | ReqInitialInsts],
        ArgNum0, !Subst, !ModeInfo) :-
    ArgNum = ArgNum0 + 1,
    mode_info_set_call_arg_context(ArgNum, !ModeInfo),
    modecheck_var_has_inst_no_exact_match(Var, ReqInitialInst,
        !Subst, !ModeInfo),
    modecheck_vars_have_insts_no_exact_match_loop(Vars, ReqInitialInsts,
        ArgNum, !Subst, !ModeInfo).

%---------------------%

:- pred modecheck_var_has_inst_exact_match(prog_var::in, mer_inst::in,
    inst_var_sub::in, inst_var_sub::out,
    mode_info::in, mode_info::out) is det.

modecheck_var_has_inst_exact_match(Var, ReqInitialInst0, !Subst, !ModeInfo) :-
    % Apply the substitution computed while matching earlier arguments.
    inst_apply_substitution(!.Subst, ReqInitialInst0, ReqInitialInst),
    mode_info_get_instmap(!.ModeInfo, InstMap),
    instmap_lookup_var(InstMap, Var, VarInst0),
    mode_info_get_var_table(!.ModeInfo, VarTable),
    lookup_var_type(VarTable, Var, Type),
    propagate_type_ho_inst_info_into_inst_update_instmap(InstMap, Var, Type,
        VarInst0, VarInst, !ModeInfo),
    mode_info_get_module_info(!.ModeInfo, ModuleInfo0),
    ( if
        inst_matches_initial_no_implied_modes_sub(Type, VarInst,
            ReqInitialInst, ModuleInfo0, ModuleInfo, !Subst)
    then
        mode_info_set_module_info(ModuleInfo, !ModeInfo)
    else
        mode_info_get_pred_var_multimode_error_map(!.ModeInfo,
            MultiModeErrorMap),
        ( if map.search(MultiModeErrorMap, Var, MultiModeError) then
            MaybeMultiModeError = yes(MultiModeError)
        else
            MaybeMultiModeError = no
        ),
        WaitingVars = set_of_var.make_singleton(Var),
        ModeError = mode_error_var_is_not_sufficiently_instantiated(Var,
            VarInst, ReqInitialInst, MaybeMultiModeError),
        mode_info_error(WaitingVars, ModeError, !ModeInfo)
    ).

:- pred modecheck_var_has_inst_no_exact_match(prog_var::in, mer_inst::in,
    inst_var_sub::in, inst_var_sub::out,
    mode_info::in, mode_info::out) is det.

modecheck_var_has_inst_no_exact_match(Var, ReqInitialInst0,
        !Subst, !ModeInfo) :-
    % Apply the substitution computed while matching earlier arguments.
    inst_apply_substitution(!.Subst, ReqInitialInst0, ReqInitialInst),
    mode_info_get_instmap(!.ModeInfo, InstMap),
    instmap_lookup_var(InstMap, Var, VarInst0),
    mode_info_get_var_table(!.ModeInfo, VarTable),
    lookup_var_type(VarTable, Var, Type),
    propagate_type_ho_inst_info_into_inst_update_instmap(InstMap, Var, Type,
        VarInst0, VarInst, !ModeInfo),
    mode_info_get_module_info(!.ModeInfo, ModuleInfo0),
    ( if
        inst_matches_initial_sub(Type, VarInst, ReqInitialInst,
            ModuleInfo0, ModuleInfo, !Subst)
    then
        mode_info_set_module_info(ModuleInfo, !ModeInfo)
    else
        mode_info_get_pred_var_multimode_error_map(!.ModeInfo,
            MultiModeErrorMap),
        ( if map.search(MultiModeErrorMap, Var, MultiModeError) then
            MaybeMultiModeError = yes(MultiModeError)
        else
            MaybeMultiModeError = no
        ),
        WaitingVars = set_of_var.make_singleton(Var),
        ModeError = mode_error_var_is_not_sufficiently_instantiated(Var,
            VarInst, ReqInitialInst, MaybeMultiModeError),
        mode_info_error(WaitingVars, ModeError, !ModeInfo)
    ).

%---------------------%

modecheck_introduced_type_info_var_has_inst_no_exact_match(Var, Type,
        ReqInitialInst, !ModeInfo) :-
    mode_info_get_instmap(!.ModeInfo, InstMap),
    instmap_lookup_var(InstMap, Var, VarInst),
    mode_info_get_module_info(!.ModeInfo, ModuleInfo0),
    ( if
        inst_matches_initial_sub(Type, VarInst, ReqInitialInst,
            ModuleInfo0, ModuleInfo, map.init, _Subst)
    then
        mode_info_set_module_info(ModuleInfo, !ModeInfo)
    else
        WaitingVars = set_of_var.make_singleton(Var),
        ModeError = mode_error_var_is_not_sufficiently_instantiated(Var,
            VarInst, ReqInitialInst, no),
        mode_info_error(WaitingVars, ModeError, !ModeInfo)
    ).

%---------------------%

:- pred modecheck_find_bound_head_inst_vars(match_what::in, exact_or_not::in,
    list(prog_var)::in, list(mer_inst)::in,  inst_var_sub::in,
    set(inst_var)::out, mode_info::in, mode_info::out) is det.

modecheck_find_bound_head_inst_vars(MatchWhat, ExactOrNot,
        Vars, ReqInitialInsts, InstVarSub, BoundInstVars, !ModeInfo) :-
    mode_info_get_head_inst_vars(!.ModeInfo, HeadInstVars),
    map.foldl(modecheck_acc_bound_head_inst_var(HeadInstVars), InstVarSub,
        set.init, BoundInstVars),
    ( if set.is_empty(BoundInstVars) then
        true
    else
        mode_info_get_instmap(!.ModeInfo, InstMap),
        WaitingVars = set_of_var.list_to_set(Vars),
        Mismatch = mode_mismatch(ExactOrNot, ReqInitialInsts, BoundInstVars),
        ModeError = mode_error_no_matching_mode(MatchWhat, InstMap, Vars,
            Mismatch, []),
        % XXX Ugly code like this should not be needed; contexts of all kinds
        % should be passed around *separately* from the mode_info.
        mode_info_get_mode_context(!.ModeInfo, ModeContext0),
        (
            ( ModeContext0 = mode_context_call_arg(CallId, _)
            ; ModeContext0 = mode_context_call(CallId)
            ),
            mode_info_set_mode_context(mode_context_call(CallId), !ModeInfo)
        ;
            ( ModeContext0 = mode_context_unify(_, _)
            ; ModeContext0 = mode_context_not_call_or_unify
            ),
            unexpected($pred, "context says we are not in a call")
        ),
        mode_info_error(WaitingVars, ModeError, !ModeInfo)
    ).

:- pred modecheck_acc_bound_head_inst_var(inst_var_sub::in,
    inst_var::in, mer_inst::in, set(inst_var)::in, set(inst_var)::out) is det.

modecheck_acc_bound_head_inst_var(HeadInstVars, InstVar, Subst,
        !BoundInstVars) :-
    ( if map.search(HeadInstVars, InstVar, Inst) then
        % Subst should not change the constraint. However, the two insts
        % may have different information about inst test results.
        ( if
            Subst = constrained_inst_vars(SubstInstVars, SubstInst),
            set.member(InstVar, SubstInstVars),
            ( if
                Inst = bound(Uniq, _, BoundFunctors),
                SubstInst = bound(SubstUniq, _, SubstBoundFunctors)
            then
                Uniq = SubstUniq,
                BoundFunctors = SubstBoundFunctors
            else
                Inst = SubstInst
            )
        then
            true
        else
            set.insert(InstVar, !BoundInstVars)
        )
    else
        true
    ).

%---------------------------------------------------------------------------%

get_var_inst(ModeInfo, Var, Inst) :-
    mode_info_get_module_info(ModeInfo, ModuleInfo),
    mode_info_get_instmap(ModeInfo, InstMap),
    mode_info_get_var_table(ModeInfo, VarTable),
    instmap_lookup_var(InstMap, Var, Inst0),
    lookup_var_type(VarTable, Var, Type),
    normalise_inst(ModuleInfo, Type, Inst0, Inst).

%---------------------------------------------------------------------------%

modecheck_set_var_inst(Var0, NewInst0, MaybeUInst, !ModeInfo) :-
    % Note that there are two versions of modecheck_set_var_inst,
    % one with arity 8 (suffixed with _call) and one with arity 5.
    % The former is used for predicate calls, where we may need
    % to introduce unifications to handle calls to implied modes.
    %
    mode_info_get_parallel_vars(!.ModeInfo, PVars0),
    mode_info_get_instmap(!.ModeInfo, InstMap0),
    ( if instmap_is_reachable(InstMap0) then
        instmap_lookup_var(InstMap0, Var0, OldInst),
        mode_info_get_module_info(!.ModeInfo, ModuleInfo0),
        % The final new inst must be computed by unifying the old inst
        % and the tentative new inst. However, abstractly unifying
        % a large inst with itself can be VERY expensive; it can be worse
        % than quadratic. The OldInst = NewInst test here may increase
        % execution time slightly in normal cases, but should reduce it
        % greatly in the worst cases.
        mode_info_get_var_table(!.ModeInfo, VarTable),
        lookup_var_type(VarTable, Var0, Type),
        ( if
            OldInst = NewInst0
        then
            ModuleInfo = ModuleInfo0,
            NewInst = NewInst0
        else if
            abstractly_unify_inst(Type, is_dead, fake_unify, OldInst, NewInst0,
                UnifyInst, _Det, ModuleInfo0, ModuleInfo1)
        then
            ModuleInfo = ModuleInfo1,
            NewInst = UnifyInst
        else
            unexpected($pred, "unify_inst failed")
        ),
        mode_info_set_module_info(ModuleInfo, !ModeInfo),
        ( if
            % If the top-level inst of the variable is not_reached,
            % then the instmap as a whole must be unreachable.
            inst_expand(ModuleInfo, NewInst, not_reached)
        then
            instmap.init_unreachable(InstMap),
            mode_info_set_instmap(InstMap, !ModeInfo)
        else if
            % If we haven't added any information and
            % we haven't bound any part of the var, then
            % the only thing we can have done is lose uniqueness.
            inst_matches_initial(ModuleInfo, Type, OldInst, NewInst)
        then
            instmap_set_var(Var0, NewInst, InstMap0, InstMap),
            mode_info_set_instmap(InstMap, !ModeInfo)
        else if
            % We must have either added some information,
            % lost some uniqueness, or bound part of the var.
            % The call to inst_matches_binding will succeed
            % only if we haven't bound any part of the var.
            not inst_matches_binding(ModuleInfo, Type, NewInst, OldInst),

            % We have bound part of the var. If the var was locked,
            % then we need to report an error ...
            mode_info_var_is_locked(!.ModeInfo, Var0, Reason0),
            not (
                % ... unless the goal is a unification and the var was unified
                % with something no more instantiated than itself. This allows
                % for the case of `any = free', for example. The call to
                % inst_matches_binding above will fail for the var with
                % mode `any >> any', however it should be allowed because
                % it has only been unified with a free variable.
                MaybeUInst = yes(UInst),
                inst_is_at_least_as_instantiated(ModuleInfo, Type,
                    NewInst, UInst),
                inst_matches_binding_allow_any_any(ModuleInfo, Type,
                    NewInst0, OldInst)
            )
        then
            WaitingVars = set_of_var.make_singleton(Var0),
            ModeError = mode_error_bind_locked_var(Reason0, Var0,
                OldInst, NewInst),
            mode_info_error(WaitingVars, ModeError, !ModeInfo)
        else
            instmap_set_var(Var0, NewInst, InstMap0, InstMap),
            mode_info_set_instmap(InstMap, !ModeInfo),
            mode_info_get_delay_info(!.ModeInfo, DelayInfo0),
            delay_info_bind_var(Var0, DelayInfo0, DelayInfo),
            mode_info_set_delay_info(DelayInfo, !ModeInfo)
        )
    else
        true
    ),
    (
        PVars0 = []
    ;
        PVars0 = [par_conj_mode_check(NonLocals, Bound0) | PVars1],
        ( if set_of_var.member(NonLocals, Var0) then
            set_of_var.insert(Var0, Bound0, Bound),
            PVars = [par_conj_mode_check(NonLocals, Bound) | PVars1]
        else
            PVars = PVars0
        ),
        mode_info_set_parallel_vars(PVars, !ModeInfo)
    ).

%---------------------------------------------------------------------------%

modecheck_set_var_insts(ArgOffset, Vars0, InitialInsts, FinalInsts,
        Vars, ExtraGoals, !ModeInfo) :-
    modecheck_set_var_insts_loop(ArgOffset, Vars0, InitialInsts, FinalInsts,
        Vars, no_extra_goals, ExtraGoals, !ModeInfo).

:- pred modecheck_set_var_insts_loop(modecheck_arg_offset::in,
    list(prog_var)::in, list(mer_inst)::in, list(mer_inst)::in,
    list(prog_var)::out, extra_goals::in, extra_goals::out,
    mode_info::in, mode_info::out) is det.

modecheck_set_var_insts_loop(ArgOffset0, Vars0, InitialInsts, FinalInsts,
        Vars, !ExtraGoals, !ModeInfo) :-
    ( if
        Vars0 = [HeadVar0 | TailVars0],
        InitialInsts = [HeadInitialInst | TailInitialInsts],
        FinalInsts = [HeadFinalInst | TailFinalInsts]
    then
        ArgOffset0 = modecheck_arg_offset(ArgNum0),
        ArgNum = ArgNum0 + 1,
        ArgOffset = modecheck_arg_offset(ArgNum),
        mode_info_set_call_arg_context(ArgNum, !ModeInfo),
        modecheck_set_var_inst_call(HeadVar0, HeadInitialInst, HeadFinalInst,
            HeadVar, !ExtraGoals, !ModeInfo),
        modecheck_set_var_insts_loop(ArgOffset, TailVars0,
            TailInitialInsts, TailFinalInsts, TailVars,
            !ExtraGoals, !ModeInfo),
        Vars = [HeadVar | TailVars]
    else if
        Vars0 = [],
        InitialInsts = [],
        FinalInsts = []
    then
        Vars = []
    else
        unexpected($pred, "length mismatch")
    ).

:- pred modecheck_set_var_inst_call(prog_var::in, mer_inst::in, mer_inst::in,
    prog_var::out, extra_goals::in, extra_goals::out,
    mode_info::in, mode_info::out) is det.

modecheck_set_var_inst_call(Var0, InitialInst, FinalInst, Var,
        !ExtraGoals, !ModeInfo) :-
    mode_info_get_instmap(!.ModeInfo, InstMap0),
    ( if instmap_is_reachable(InstMap0) then
        instmap_lookup_var(InstMap0, Var0, VarInst0),
        handle_implied_mode(Var0, VarInst0, InitialInst, Var,
            !ExtraGoals, !ModeInfo),
        % The new inst must be computed by unifying the old inst
        % and the proc's final inst; modecheck_set_var_inst will do this.
        modecheck_set_var_inst(Var0, FinalInst, no, !ModeInfo),
        ( if Var = Var0 then
            true
        else
            modecheck_set_var_inst(Var, FinalInst, no, !ModeInfo)
        )
    else
        Var = Var0
    ).

%---------------------%

    % If this was a call to an implied mode for that variable, then we need to
    % introduce a fresh variable.
    %
:- pred handle_implied_mode(prog_var::in, mer_inst::in, mer_inst::in,
    prog_var::out, extra_goals::in, extra_goals::out,
    mode_info::in, mode_info::out) is det.

handle_implied_mode(Var0, VarInst0, InitialInst0, Var,
        !ExtraGoals, !ModeInfo) :-
    mode_info_get_module_info(!.ModeInfo, ModuleInfo0),
    inst_expand(ModuleInfo0, InitialInst0, InitialInst),
    inst_expand(ModuleInfo0, VarInst0, VarInst1),

    mode_info_get_var_table(!.ModeInfo, VarTable0),
    lookup_var_type(VarTable0, Var0, VarType),
    ( if
        % If the initial inst of the variable matches_final the initial inst
        % specified in the pred's mode declaration, then it is not a call
        % to an implied mode, it is an exact match with a genuine mode.
        inst_matches_initial_no_implied_modes_sub(VarType,
            VarInst1, InitialInst, ModuleInfo0, _ModuleInfo, map.init, _Sub)
    then
        Var = Var0
    else
        % This is the implied mode case.
        ( if
            InitialInst = any(_, _),
            inst_is_free(ModuleInfo0, VarInst1)
        then
            % This is the simple case of implied `any' modes, where
            % the declared mode was `any -> ...' and the argument passed
            % was `free'.
            Var = Var0,

            % If the variable's type is not a solver type (in which case
            % inst `any' means the same as inst `ground') then this is
            % an implied mode that we don't yet know how to handle.
            % XXX I (zs) see no test for solver types here.
            WaitingVars = set_of_var.make_singleton(Var0),
            ModeError = mode_error_cannot_create_implied_mode(cannot_init_any,
                Var0, VarInst0, InitialInst),
            mode_info_error(WaitingVars, ModeError, !ModeInfo)
        else if
            inst_is_bound(ModuleInfo0, InitialInst)
        then
            % We do not yet handle implied modes for partially instantiated
            % vars, since that would require doing a partially instantiated
            % deep copy, and we don't know how to do that yet.
            Var = Var0,
            WaitingVars = set_of_var.make_singleton(Var0),
            Reason = cannot_deep_copy_partial_term,
            ModeError = mode_error_cannot_create_implied_mode(Reason,
                Var0, VarInst0, InitialInst),
            mode_info_error(WaitingVars, ModeError, !ModeInfo)
        else
            % This is the simple case of implied modes,
            % where the declared mode was free -> ...

            % Introduce a new variable.
            VarIsDummy = is_type_a_dummy(ModuleInfo0, VarType),
            VarEntry = vte("", VarType, VarIsDummy),
            add_var_entry(VarEntry, Var, VarTable0, VarTable),
            mode_info_set_var_table(VarTable, !ModeInfo),

            % Construct the code to do the unification.
            create_var_var_unification(Var0, Var, VarType, !.ModeInfo,
                ExtraGoal),

            % Append the goals together in the appropriate order:
            % ExtraGoals0, then NewUnify.
            NewUnifyExtraGoal = extra_goals([], [ExtraGoal]),
            append_extra_goals(!.ExtraGoals, NewUnifyExtraGoal, !:ExtraGoals)
        )
    ).

%---------------------------------------------------------------------------%

mode_info_add_goals_live_vars(_ConjType, [], !ModeInfo).
mode_info_add_goals_live_vars(ConjType, [Goal | Goals], !ModeInfo) :-
    % We add the live vars for the goals in the goal list in reverse order,
    % because this ensures that in the common case (where there is no
    % delaying), when we come to remove the live vars for the first goal
    % they will have been added last and will thus be at the start of the list
    % of live vars sets, which makes them cheaper to remove.
    mode_info_add_goals_live_vars(ConjType, Goals, !ModeInfo),
    ( if
        % Recurse into conjunctions, in case there are any conjunctions
        % that have not been flattened.
        Goal = hlds_goal(conj(ConjType, ConjGoals), _)
    then
        mode_info_add_goals_live_vars(ConjType, ConjGoals, !ModeInfo)
    else
        NonLocals = goal_get_nonlocals(Goal),
        mode_info_add_live_vars(NonLocals, !ModeInfo)
    ).

mode_info_remove_goals_live_vars([], !ModeInfo).
mode_info_remove_goals_live_vars([Goal | Goals], !ModeInfo) :-
    ( if
        % Recurse into conjunctions, in case there are any conjunctions
        % that have not been flattened.
        Goal = hlds_goal(conj(plain_conj, ConjGoals), _)
    then
        mode_info_remove_goals_live_vars(ConjGoals, !ModeInfo)
    else
        NonLocals = goal_get_nonlocals(Goal),
        mode_info_remove_live_vars(NonLocals, !ModeInfo)
    ),
    mode_info_remove_goals_live_vars(Goals, !ModeInfo).

%---------------------------------------------------------------------------%

modecheck_record_functor_test(Var, ConsId, !ModeInfo) :-
    % Figure out the arity of this constructor, _including_ any type-infos
    % or typeclass-infos inserted for existential data types.
    mode_info_get_module_info(!.ModeInfo, ModuleInfo),
    mode_info_get_var_table(!.ModeInfo, VarTable),
    lookup_var_type(VarTable, Var, Type),
    BoundFunctor = cons_id_to_bound_functor(ModuleInfo, Type, ConsId),

    % Record the fact that Var was bound to ConsId.
    Inst = bound(unique, inst_test_no_results, [BoundFunctor]),
    modecheck_set_var_inst(Var, Inst, no, !ModeInfo).

modecheck_record_functors_test(Var, MainConsId, OtherConsIds, !ModeInfo) :-
    % Figure out the arity of this constructor, _including_ any type-infos
    % or typeclass-infos inserted for existential data types.
    mode_info_get_module_info(!.ModeInfo, ModuleInfo),
    mode_info_get_var_table(!.ModeInfo, VarTable),
    lookup_var_type(VarTable, Var, Type),
    BoundFunctors = list.map(cons_id_to_bound_functor(ModuleInfo, Type),
        [MainConsId | OtherConsIds]),

    % Record the fact that Var was bound to MainConsId or one of the
    % OtherConsIds.
    Inst = bound(unique, inst_test_no_results, BoundFunctors),
    modecheck_set_var_inst(Var, Inst, no, !ModeInfo).

:- func cons_id_to_bound_functor(module_info, mer_type, cons_id)
    = bound_functor.

cons_id_to_bound_functor(ModuleInfo, Type, ConsId) = BoundFunctor :-
    ( if ConsId = du_data_ctor(DuCtor) then
        ConsIdArity = du_ctor_adjusted_arity(ModuleInfo, Type, DuCtor)
    else
        ConsIdArity = cons_id_arity(ConsId)
    ),
    list.duplicate(ConsIdArity, free, ArgInsts),
    BoundFunctor = bound_functor(ConsId, ArgInsts).

%---------------------------------------------------------------------------%

compute_goal_instmap_delta(InstMap0, GoalExpr, !GoalInfo, !ModeInfo) :-
    ( if GoalExpr = conj(_, []) then
        % When modecheck_unify.m replaces a unification with a dead variable
        % with `true', make sure the instmap_delta of the goal is empty.
        % The code generator and mode_util.recompute_instmap_delta can be
        % confused by references to the dead variable in the instmap_delta,
        % resulting in calls to error/1.
        instmap_delta_init_reachable(InstMapDelta),
        mode_info_set_instmap(InstMap0, !ModeInfo)
    else
        NonLocals = goal_info_get_nonlocals(!.GoalInfo),
        mode_info_get_instmap(!.ModeInfo, InstMap),
        compute_instmap_delta(InstMap0, InstMap, NonLocals, InstMapDelta)
    ),
    goal_info_set_instmap_delta(InstMapDelta, !GoalInfo).

%---------------------------------------------------------------------------%

mode_context_to_unify_context(ModeInfo, ModeContext, UnifyContext) :-
    (
        ModeContext = mode_context_unify(UnifyContext, _)
    ;
        ModeContext = mode_context_call_arg(ModeCallId, Arg),
        CallId = mode_call_id_to_call_id(ModeInfo, ModeCallId),
        UnifyContext = unify_context(umc_call(CallId, Arg), [])
    ;
        ModeContext = mode_context_call(_),
        unexpected($pred, "context is *all* of a call")
    ;
        ModeContext = mode_context_not_call_or_unify,
        unexpected($pred, "context not call or unify")
    ).

mode_call_id_to_call_id(ModeInfo, ModeCallId) = CallId :-
    (
        ModeCallId = mode_call_plain(PredId),
        mode_info_get_pf_sym_name_arity(ModeInfo, PredId, PFSymNameArity),
        CallId = plain_call_id(PFSymNameArity)
    ;
        ModeCallId = mode_call_generic(GenericCall),
        mode_info_get_var_table(ModeInfo, VarTable),
        CallId = generic_call_id(vns_var_table(VarTable), GenericCall)
    ).

%---------------------------------------------------------------------------%

get_live_vars([], [], []).
get_live_vars([_ | _], [], _) :-
    unexpected($pred, "length mismatch").
get_live_vars([], [_ | _], _) :-
    unexpected($pred, "length mismatch").
get_live_vars([Var | Vars], [IsLive | IsLives], LiveVars) :-
    (
        IsLive = is_live,
        LiveVars = [Var | LiveVars0]
    ;
        IsLive = is_dead,
        LiveVars = LiveVars0
    ),
    get_live_vars(Vars, IsLives, LiveVars0).

%---------------------------------------------------------------------------%

:- type inst_expansions == set_tree234(inst_name).

get_constrained_inst_vars(ModuleInfo, Modes, Map) :-
    list.foldl2(get_constrained_insts_in_mode(ModuleInfo), Modes,
        map.init, Map, set_tree234.init, _Expansions).

:- pred get_constrained_insts_in_mode(module_info::in, mer_mode::in,
    head_inst_vars::in, head_inst_vars::out,
    inst_expansions::in, inst_expansions::out) is det.

get_constrained_insts_in_mode(ModuleInfo, Mode, !Map, !Expansions) :-
    mode_get_insts(ModuleInfo, Mode, InitialInst, FinalInst),
    get_constrained_insts_in_inst(ModuleInfo, InitialInst, !Map, !Expansions),
    get_constrained_insts_in_inst(ModuleInfo, FinalInst, !Map, !Expansions).

:- pred get_constrained_insts_in_inst(module_info::in, mer_inst::in,
    head_inst_vars::in, head_inst_vars::out,
    inst_expansions::in, inst_expansions::out) is det.

get_constrained_insts_in_inst(ModuleInfo, Inst, !Map, !Expansions) :-
    (
        ( Inst = free
        ; Inst = not_reached
        )
    ;
        Inst = bound(_, InstResults, BoundFunctors),
        (
            InstResults = inst_test_results_fgtc
        ;
            InstResults = inst_test_results(_, _, _, InstVarsResult, _, _),
            ( if
                InstVarsResult =
                    inst_result_contains_inst_vars_known(InstVars),
                set.is_empty(InstVars)
            then
                true
            else
                list.foldl2(get_constrained_insts_in_bound_functor(ModuleInfo),
                    BoundFunctors, !Map, !Expansions)
            )
        ;
            InstResults = inst_test_no_results,
            list.foldl2(get_constrained_insts_in_bound_functor(ModuleInfo),
                BoundFunctors, !Map, !Expansions)
        )
    ;
        ( Inst = any(_, HOInstInfo)
        ; Inst = ground(_, HOInstInfo)
        ),
        (
            HOInstInfo = none_or_default_func
        ;
            HOInstInfo = higher_order(PredInstInfo),
            get_constrained_insts_in_ho_inst(ModuleInfo, PredInstInfo,
                !Map, !Expansions)
        )
    ;
        Inst = constrained_inst_vars(InstVars, _),
        inst_expand_and_remove_constrained_inst_vars(ModuleInfo,
            Inst, SubInst),
        set.fold(add_constrained_inst(SubInst), InstVars, !Map)
    ;
        Inst = defined_inst(InstName),
        ( if insert_new(InstName, !Expansions) then
            inst_lookup(ModuleInfo, InstName, ExpandedInst),
            get_constrained_insts_in_inst(ModuleInfo, ExpandedInst,
                !Map, !Expansions)
        else
            true
        )
    ;
        Inst = inst_var(_),
        unexpected($pred, "inst_var")
    ).

:- pred get_constrained_insts_in_bound_functor(module_info::in,
    bound_functor::in, head_inst_vars::in, head_inst_vars::out,
    inst_expansions::in, inst_expansions::out) is det.

get_constrained_insts_in_bound_functor(ModuleInfo, BoundFunctor,
        !Map, !Expansions) :-
    BoundFunctor = bound_functor(_ConsId, Insts),
    list.foldl2(get_constrained_insts_in_inst(ModuleInfo), Insts,
        !Map, !Expansions).

:- pred get_constrained_insts_in_ho_inst(module_info::in, pred_inst_info::in,
    head_inst_vars::in, head_inst_vars::out,
    inst_expansions::in, inst_expansions::out) is det.

get_constrained_insts_in_ho_inst(ModuleInfo, PredInstInfo,
        !Map, !Expansions) :-
    PredInstInfo = pred_inst_info(_, Modes, _, _),
    list.foldl2(get_constrained_insts_in_mode(ModuleInfo), Modes,
        !Map, !Expansions).

:- pred add_constrained_inst(mer_inst::in, inst_var::in,
    head_inst_vars::in, head_inst_vars::out) is det.

add_constrained_inst(SubInst, InstVar, !Map) :-
    ( if map.search(!.Map, InstVar, SubInst0) then
        ( if SubInst0 = SubInst then
            true
        else
            unexpected($pred, "SubInst differs")
        )
    else
        map.det_insert(InstVar, SubInst, !Map)
    ).

%---------------------------------------------------------------------------%

fixup_instmap_switch_var(Var, InstMap0, InstMap, Goal0, Goal) :-
    Goal0 = hlds_goal(GoalExpr, GoalInfo0),
    InstMapDelta0 = goal_info_get_instmap_delta(GoalInfo0),
    instmap_lookup_var(InstMap0, Var, Inst0),
    instmap_lookup_var(InstMap, Var, Inst),
    ( if Inst = Inst0 then
        Goal = Goal0
    else
        instmap_delta_set_var(Var, Inst, InstMapDelta0, InstMapDelta),
        goal_info_set_instmap_delta(InstMapDelta, GoalInfo0, GoalInfo),
        Goal = hlds_goal(GoalExpr, GoalInfo)
    ).

%---------------------------------------------------------------------------%

normalise_inst(ModuleInfo, Type, Inst0, NormalisedInst) :-
    % This is a bit of a hack.
    % The aim is to avoid non-termination due to the creation
    % of ever-expanding insts.
    % XXX should also normalise partially instantiated insts.

    inst_expand(ModuleInfo, Inst0, Inst),
    ( if Inst = bound(_, _, _) then
        ( if
            % Don't infer unique modes for introduced type_info arguments,
            % because that leads to an increase in the number of inferred modes
            % without any benefit.
            not is_introduced_type_info_type(Type),

            inst_is_ground(ModuleInfo, Type, Inst),
            ( if inst_is_unique(ModuleInfo, Inst) then
                Uniq = unique
            else if inst_is_mostly_unique(ModuleInfo, Inst) then
                Uniq = mostly_unique
            else
                fail
            ),
            not inst_contains_nondefault_func_mode(ModuleInfo, Type, Inst)
        then
            NormalisedInst = ground(Uniq, none_or_default_func)
        else if
            inst_is_ground(ModuleInfo, Type, Inst),
            not inst_is_clobbered(ModuleInfo, Inst),
            not inst_contains_nondefault_func_mode(ModuleInfo, Type, Inst)
        then
            NormalisedInst = ground(shared, none_or_default_func)
        else
            % XXX We need to limit the potential size of insts here
            % in order to avoid infinite loops in mode inference.
            NormalisedInst = Inst
        )
    else
        NormalisedInst = Inst
    ).

normalise_insts(_, [], [], []).
normalise_insts(_, [], [_ | _], _) :-
    unexpected($pred, "length mismatch").
normalise_insts(_, [_ | _], [], _) :-
    unexpected($pred, "length mismatch").
normalise_insts(ModuleInfo, [Type | Types],
        [Inst0 | Insts0], [Inst | Insts]) :-
    normalise_inst(ModuleInfo, Type, Inst0, Inst),
    normalise_insts(ModuleInfo, Types, Insts0, Insts).

%---------------------------------------------------------------------------%

:- pred propagate_type_ho_inst_info_into_inst_update_instmap(instmap::in,
    prog_var::in, mer_type::in, mer_inst::in, mer_inst::out,
    mode_info::in, mode_info::out) is det.

propagate_type_ho_inst_info_into_inst_update_instmap(InstMap0, Var, Type,
        VarInst0, VarInst, !ModeInfo) :-
    propagate_type_ho_inst_info_into_inst(Type, VarInst0, VarInst),
    ( if private_builtin.pointer_equal(VarInst0, VarInst) then
        true
    else
        instmap_set_var(Var, VarInst, InstMap0, InstMap),
        mode_info_set_instmap(InstMap, !ModeInfo)
    ).

propagate_type_ho_inst_info_into_inst(Type, Inst0, Inst) :-
    ( if
        Type = higher_order_type(_, _, TypeHOInstInfo, _),
        TypeHOInstInfo = higher_order(_),
        (
            Inst0 = ground(Uniq, _),
            Inst1 = ground(Uniq, TypeHOInstInfo)
        ;
            Inst0 = any(Uniq, _),
            Inst1 = any(Uniq, TypeHOInstInfo)
        )
    then
        Inst = Inst1
    else
        Inst = Inst0
    ).

%---------------------------------------------------------------------------%
:- end_module check_hlds.modecheck_util.
%---------------------------------------------------------------------------%
