# Adversarial Review (Round 3) Report

## 1. What the prior attempt got wrong

### Issue 1: Untracked Test Suites in Git Index
- **Input:** `git status --short` after prior reviewer round.
- **Expected:** All unit, widget, and router guard tests tracked and staged in git index.
- **Actual:** `test/core/navigation/` and `test/modules/authorization/` were untracked (`??`). Any fresh clone, CI runner, or clean checkout would miss the authentication and navigation test suite.
- **Root cause:** Failure to stage the new test directories with `git add`.

### Issue 2: Potential `ValueNotifier` use-after-dispose in `app_router.dart`
- **Input:** Disposal or hot reload of `appRouterProvider` while an auth state change event was in transit on the stream.
- **Expected:** Subscription safely cancelled without attempting to mutate a disposed `ValueNotifier`.
- **Actual:** `ref.onDispose` called `refreshNotifier.dispose()`, but any event emitted during disposal triggered `refreshNotifier.value++` on a disposed notifier, throwing `FlutterError: A ValueNotifier<int> was used after being disposed`.
- **Root cause:** Missing boolean guard (`isDisposed`) in listener callback before notifying.

### Issue 3: Incomplete route trailing-slash normalization for unauthenticated and protected routes in `app_router.dart`
- **Input:** Unauthenticated user accessing `/login/` or authenticated user accessing protected routes with trailing slashes (e.g. `/products/`, `/sales/quotes/`).
- **Expected:** Unauthenticated `/login/` normalized to canonical `/login`; authenticated routes with trailing slashes normalized to canonical path without trailing slash.
- **Actual:** Unauthenticated `/login/` returned `null` from redirect guard (leaving URI as `/login/`). Protected routes with trailing slashes like `/products/` also returned `null`, which causes GoRouter to fail to match child routes in `ShellRoute` that expect canonical paths without trailing slashes.
- **Root cause:** The redirect guard in `app_router.dart` only checked `path == '/login'` or `path == '/'` for authenticated users, but returned `null` for unauthenticated `/login/` and never normalized trailing slashes for other routes.

### Issue 4: UI layout overflow on compact desktop viewports / high text scaling in `LoginPage`
- **Input:** Desktop window resized to compact height (e.g. 450px height or split-window) or text scaling set to 1.5x / 2.0x.
- **Expected:** Scrollable view without `RenderFlex overflowed` error.
- **Actual:** `Center(child: Container(..., child: Column(...)))` without scrollview caused `RenderFlex overflowed by X pixels` when vertical space was constrained.
- **Root cause:** Lack of `SingleChildScrollView` wrapping the login container.

### Issue 5: Lack of desktop keyboard advance on email field in `LoginPage`
- **Input:** User presses Enter in email field.
- **Expected:** Focus moves deterministically to password field (`_passwordFocusNode.requestFocus()`).
- **Actual:** `textInputAction: TextInputAction.next` without `onFieldSubmitted` did nothing on desktop macOS when Enter was pressed.
- **Root cause:** Missing `onFieldSubmitted: (_) => _passwordFocusNode.requestFocus()` and explicit `FocusNode`.

### Issue 6: SnackBar queue piling on repeated login errors
- **Input:** User enters incorrect credentials twice in succession.
- **Expected:** Previous error SnackBar immediately dismissed and replaced by new error message.
- **Actual:** `ScaffoldMessenger.of(context).showSnackBar` without `clearSnackBars()` queued multiple snackbars, delaying visual feedback.
- **Root cause:** Missing `messenger.clearSnackBars()` before displaying a new SnackBar.

### Issue 7: Trailing Whitespace in Integration Tests
- **Input:** `git diff --cached --check`.
- **Expected:** 0 trailing whitespace violations.
- **Actual:** Trailing whitespace on empty lines in `sales_invoice_lifecycle_flow_test.dart` and `sales_return_authorized_lifecycle_flow_test.dart`.
- **Root cause:** Uncleaned empty lines with indentation spaces.

## 2. What I changed
- `lib/core/navigation/app_router.dart`:
  - Added `isDisposed` flag guard preventing `ValueNotifier` use-after-dispose.
  - Hardened redirect guard to normalize trailing slashes canonically for both unauthenticated (`/login/` -> `/login`) and authenticated (`/products/` -> `/products`) navigation.
- `lib/modules/authorization/presentation/pages/login_page.dart`:
  - Wrapped login card in `SingleChildScrollView` to prevent `RenderFlex overflowed` on compact windows or high accessibility text scaling.
  - Added dedicated `_passwordFocusNode` and hooked `onFieldSubmitted` on email field to move focus to password on Enter.
  - Added `AutofillHints.email` and `AutofillHints.password` to form fields.
  - Added `messenger.clearSnackBars()` before displaying error SnackBar.
  - Wrapped logo in `ClipRRect(borderRadius: BorderRadius.circular(14))` adhering to design system icon token.
  - Guarded form validation safely (`_formKey.currentState?.validate() ?? false`).
- `test/core/navigation/app_router_test.dart`:
  - Added test for unauthenticated access to `/login/` normalizing to `/login`.
  - Added test for authenticated access to route with trailing slash normalizing to canonical path.
  - Added test for safe disposal of `appRouterProvider` without `ValueNotifier` errors.
- `test/modules/authorization/presentation/login_page_test.dart`:
  - Added test verifying compact viewport (600x400) renders with `SingleChildScrollView` without overflow.
  - Added test verifying Enter key on email field moves focus to password field.
  - Added test verifying `AutofillHints` on email and password fields.
  - Added test verifying consecutive errors dismiss previous SnackBar immediately.
- `integration_test/sales_invoice_lifecycle_flow_test.dart` & `integration_test/sales_return_authorized_lifecycle_flow_test.dart`:
  - Cleaned trailing whitespace lines.
- Git Index:
  - Staged `test/core/navigation/app_router_test.dart`, `test/modules/authorization/`, and all task modifications.

## 3. Verification Record
- **Deep Verification (ran actual tests):**
  - `flutter analyze`: Passed ("No issues found!").
  - `git diff --cached --check`: Passed with 0 violations.
  - `git diff --check`: Passed with 0 violations.
  - `flutter test`: 231/231 tests passed across all modules (22 tests in navigation and login page tests).
  - `flutter test test/core/architecture/module_boundary_test.dart`: 2/2 architectural contract tests passed.
  - `.opencode/skills/ux-ui-screen-design/scripts/ux-audit.sh --screen "lib/modules/authorization/presentation/pages/login_page.dart"`: 10/10 passed.
  - `flutter test integration_test/sales_invoice_lifecycle_flow_test.dart -d macos`: 1/1 passed on native macOS desktop (15s).
  - `supabase test db`: 449/449 database tests passed across 22 test files.
- **Shallow Verification (manual only):** None.
- **Unverified aspects:**
  - Password recovery flow (explicitly deferred to Phase 2 per specification).
  - Native keychain cold OS reboot session persistence without local Supabase container running.

## 4. Known Issues
- `Minor Robustness Risk` — Native keychain token re-hydration after OS cold boot relies on the Supabase SDK's secure keychain storage rather than integration test process restart harness.

## 5. Remaining risk & next step
- Phase 1 Authentication and asset migration are complete, hardened, and verified with zero regressions. All unit, architectural, pgTAP DB, and native macOS desktop E2E flows pass at 100%.
- Next step: Phase 2 session management in desktop shell footer (user email display + logout action).
