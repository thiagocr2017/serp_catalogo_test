# Round 1 Adversarial Review Report

> [!WARNING] **Skepticism Disclaimer**
> Highly confident in the automated verification across unit, architectural, UX governance, and macOS E2E tests, but native offline session persistence across OS-level process reboots remains verified only through Supabase SDK contracts rather than cold process restarts.

## 1. What the prior attempt got wrong

### Issue 1: `currentUserProvider` non-reactive stale cache
- **Input:** Login or logout triggering `authStateChanges` event on `AuthRepository`.
- **Expected:** `currentUserProvider` invalidates and emits the updated `User?` to listeners.
- **Actual:** `currentUserProvider` was a static `Provider` reading `repository.currentUser` without subscribing to `authStateChanges` or calling `ref.invalidateSelf()`. Once computed, it permanently returned `null`.
- **Root cause:** Missing stream event listener and self-invalidation trigger inside `currentUserProvider` in `lib/modules/authorization/api/auth_api.dart`.

### Issue 2: Incomplete `AuthRepository` contract (missing `signOut`)
- **Input:** Invoking `signOut()` via public `AuthRepository` interface.
- **Expected:** Method exists on the contract as required by `.specs/screens/login/2.technical-plan.md` and `3.tasks.md`.
- **Actual:** `signOut()` was implemented on `SupabaseAuthRepository`, but omitted from the interface `AuthRepository` in `api/auth_api.dart`, preventing consumers of the provider from signing out.
- **Root cause:** Public contract omission in `lib/modules/authorization/api/auth_api.dart`.

### Issue 3: Asynchronous `LoginController` initial loading flash & re-entrancy vulnerability
- **Input:** Mounting `LoginPage` or attempting immediate login submission.
- **Expected:** Initial controller state is synchronous `AsyncData(null)` and blocks duplicate concurrent submissions when `state.isLoading`.
- **Actual:** `LoginController` extended `AsyncNotifier<void>` with an `async build()` returning `Future<void>`, causing an initial `AsyncLoading` state on mount. Adding a naïve `if (state.isLoading) return;` completely blocked valid login attempts on initial frame.
- **Root cause:** Using `AsyncNotifier<void>` with async build instead of `Notifier<AsyncValue<void>>` with synchronous `build() => const AsyncData(null)`.

### Issue 4: UX & Accessibility failures against project visual governance
- **Input:** Running `.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh` on `LoginPage`.
- **Expected:** 10/10 automated UX checks pass (Semantics, tooltips, labeled images, squircle button styling).
- **Actual:** Failed with 2 errors: `Semántica accesible` and `Iconos/imagenes con etiqueta` because `Image.asset` lacked `semanticLabel`, no `Semantics` container existed, and buttons lacked the 8px squircle requirement from `1.requirements.spec.md`.
- **Root cause:** Incomplete accessibility attributes and non-adherence to macOS Precision Enterprise visual governance in `lib/modules/authorization/presentation/pages/login_page.dart` and `lib/shared/widgets/desktop_shell_widget.dart`.

### Issue 5: Unmanaged `ValueNotifier` resource leak in `app_router.dart`
- **Input:** `appRouterProvider` disposal in test containers or app restart.
- **Expected:** Both the stream subscription and `ValueNotifier` are disposed.
- **Actual:** Only `subscription.cancel()` was called; `refreshNotifier.dispose()` was never called.
- **Root cause:** Missing notifier disposal in `ref.onDispose`.

### Issue 6: Raw exception exposure in user feedback
- **Input:** Authentication failure (e.g. wrong password).
- **Expected:** Clean message such as "Error de inicio de sesión: Invalid login credentials".
- **Actual:** String interpolation exposed raw `AuthException(message: ..., statusCode: ...)`.
- **Root cause:** Not extracting `(next.error as AuthException).message` in `LoginPage`.

### Issue 7: Fragile E2E fixtures on database reset
- **Input:** `supabase db reset` wiping `auth.users`.
- **Expected:** E2E test automatically provisions or recovers `e2e-fixture@example.test` before executing test assertions.
- **Actual:** Test assumed pre-existing fixture, causing test execution failures if a db reset occurred without manual intervention.
- **Root cause:** Absence of idempotent test fixture self-provisioning in `sales_invoice_lifecycle_flow_test.dart` and `sales_return_authorized_lifecycle_flow_test.dart`.

## 2. What I changed
- `lib/modules/authorization/api/auth_api.dart`:
  - Added `Future<void> signOut();` to `AuthRepository` interface.
  - Added `authStateChangesProvider` (StreamProvider) and refactored `currentUserProvider` to subscribe to `authStateChanges` with `ref.invalidateSelf()` and `ref.onDispose`.
- `lib/modules/authorization/data/auth_repository.dart`:
  - Added `@override` annotation to `signOut()`.
- `lib/modules/authorization/presentation/controllers/login_controller.dart`:
  - Refactored `LoginController` to `Notifier<AsyncValue<void>>` with synchronous `build() => const AsyncData(null)` and guarded against duplicate submissions while loading.
- `lib/modules/authorization/presentation/pages/login_page.dart`:
  - Added `Semantics` wrapper and `semanticLabel` to logo image.
  - Added keyboard actions (`TextInputAction.next`, `TextInputAction.done`, `onFieldSubmitted` submitting via Enter).
  - Cleaned up `AuthException` message presentation in SnackBar.
  - Implemented squircle button styling (`borderRadius: 8`, 44px min height).
  - Added whitespace trimming to input validators.
- `lib/shared/widgets/desktop_shell_widget.dart`:
  - Added `semanticLabel: 'Logo de SERP'` to logo image.
- `lib/core/navigation/app_router.dart`:
  - Added `refreshNotifier.dispose()` in `ref.onDispose`.
  - Replaced `ref.read` with `ref.watch(authRepositoryProvider)`.
- `test/widget_test.dart`:
  - Added `signOut()` to `_FakeAuthRepository`.
- `test/modules/authorization/presentation/login_page_test.dart`:
  - Added `signOut()` to `_MockAuthRepository`.
  - Added tests for whitespace validation, Enter key submission, and clean SnackBar errors.
- `test/modules/authorization/api/auth_api_test.dart`:
  - Added comprehensive tests for `currentUserProvider` reactive lifecycle and `authStateChangesProvider`.
- `test/modules/authorization/presentation/controllers/login_controller_test.dart`:
  - Added tests for `LoginController` state machine and concurrent execution rejection.
- `test/core/navigation/app_router_test.dart`:
  - Added tests verifying unauthenticated redirect to `/login`, authenticated redirect to `/products`, and reactive logout redirect.
- `integration_test/sales_invoice_lifecycle_flow_test.dart` & `integration_test/sales_return_authorized_lifecycle_flow_test.dart`:
  - Added idempotent self-healing fixture provisioning via local Supabase admin client.

## 3. Verification Record
- **Deep Verification (ran actual tests):**
  - `.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh --screen "lib/modules/authorization/presentation/pages/login_page.dart"`: Passed 10/10 checks.
  - `flutter analyze`: Passed with "No issues found!".
  - `flutter test`: 218/218 unit and widget tests passed (0 failures).
  - `flutter test test/core/architecture/module_boundary_test.dart`: 2/2 architectural contract tests passed.
  - `flutter test integration_test/sales_invoice_lifecycle_flow_test.dart -d macos`: Passed completely on native macOS desktop.
  - `flutter test integration_test/sales_return_authorized_lifecycle_flow_test.dart -d macos`: Passed completely on native macOS desktop.
  - `supabase test db`: 449/449 pgTAP database contract tests passed across 22 test files.
- **Shallow Verification (manual only):**
  - None.
- **Unverified aspects:**
  - Password recovery flow (out of scope for Phase 1 as noted in `.specs/screens/login/1.requirements.spec.md`).
  - Native offline session expiry persistence across app reboots (handled by Supabase SDK default persistence, not tested across actual process restart).

## 4. Known Issues
- `Minor Robustness Risk` — Native offline session expiry across actual cold macOS application restarts relies on Supabase SDK's secure storage implementation and is not covered by the current integration test suite.

## 5. Remaining risk & next step
- Phase 1 Authentication and visual asset consolidation are fully verified and hardened against regressions.
- Next step for Phase 2: Implement User Profile / Session widget in Desktop Shell sidebar footer showing current user email and a "Cerrar Sesión" action invoking `authRepository.signOut()`.
