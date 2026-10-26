![Banner](https://github.com/Thanasis-Traitsis/flutter_tap_notifications/blob/main/assets/What%20Really%20Happens%20When%20You%20Tap%20a%20Push%20Notification%20in%20Flutter.png?raw=true)

In my last article, we went deep into local notifications. *Really* deep. Channels, permissions, timezones, the OS scheduler... And at the very end, I made you a promise: a Part 2 about push notifications.

Well, here we are. Sort of. 😅

Push notifications are a huge world. FCM, APNs, servers, tokens, payloads. Throwing all of that at you in one article wouldn't be fair, to you or to me. So today, let's investigate the notification world a little further, starting with the one part your users actually touch. **The tap.**

Have you ever tapped a notification from an app you use every day, and landed... on the home screen? Not the article. Not the new episode. Just the home screen, as if the notification never happened. You tap. The app opens. And nothing.

That's exactly what I wanted to avoid while building [ήτα.ρώ](https://ita-ro.gr/), the radio app of Iraklis Thessaloniki. The app sends a push for a few different things: a show going live, a new article, a change in the weekly schedule. And every one of those taps has to take you somewhere different.

Simple, right? **Here's the thing:** a tap doesn't always arrive the same way. It depends on what your app was doing when the user pressed it:
- **The app is open** → the user is right there, looking at it
- **The app is in the background** → minimized, still alive in memory
- **The app is dead** → swiped away, or killed by the OS

Three states. Three different paths into your app. Miss one, and that's the tap that drops your users on the home screen.

So here's the plan. We'll go through the three scenarios one by one and point at the exact lines of code that make each tap land on the right screen. No 30-minute read this time, I promise. We won't set up Firebase from scratch or build a server that sends pushes. Just the journey from *"user taps"* to *"user sees the right screen"*.

![Let's begin](https://github.com/Thanasis-Traitsis/flutter_tap_notifications/blob/main/assets/tap_intro.gif)

Let's begin.

## The tools we need

For this article, I built a small sample app: a tiny radio app with three tabs (**Live**, **Schedule** and **Articles**) and an article details screen. Same idea as ήτα.ρώ, without all the extra features. Here's what it uses:

- [**firebase_messaging**](https://pub.dev/packages/firebase_messaging) → receives the pushes, and tells us when the user taps one. It's the star of today's show.
- [**flutter_local_notifications**](https://pub.dev/packages/flutter_local_notifications) → yes, our old friend from the last article. You'll see in a minute why a *push* article needs a *local* notification package.
- [**go_router**](https://pub.dev/packages/go_router) → navigation. And more importantly, navigation **without a `BuildContext`**, because a notification tap doesn't come from any widget.
- [**flutter_bloc**](https://pub.dev/packages/flutter_bloc) → holds the splash state. This one plays a small but very important role in Scenario 3.

Firebase itself (creating the project, `flutterfire configure`, uploading the APNs key for iOS) is covered really well in the [official FlutterFire docs](https://firebase.google.com/docs/cloud-messaging/flutter/client), so I won't repeat it here.

#### The payload: a tiny contract

Before we tap anything, we need to agree on one thing. When the server sends a push, it attaches some extra `data` to it, and that's the only thing our app will use to decide where to go:

```json
{
  "notification": { "title": "New article!", "body": "The derby, live from the stadium" },
  "data": { "type": "article", "reference_id": "1" }
}
```

The `notification` part is what the user reads. The `data` part is what **our code** reads. Two keys, that's it:
- `type` → what kind of notification this is
- `reference_id` → which specific thing it's about (only needed for articles)

On the Flutter side, `type` maps to a simple enum:

```dart
/// Must match the `type` value your server puts in the push `data`.
enum NotificationType { live, schedule, article }
```

**Treat this like an API contract.** Your server and your app have to speak the same language, and the day you add a new type on the server, older versions of your app will receive a `type` they've never heard of. We'll make sure that doesn't crash anything.

And with that, we're ready for our first scenario. Spoiler: it's the one that surprised me the most.

## Scenario 1: The app is open

Here's a confession. I was *sure* this scenario worked in ήτα.ρώ. I mean, if pushes work when the app is closed, they surely work when it's open, right?

So I opened the app, went to the Socials tab, and triggered a "we're live" push from the backend.

Nothing. No banner at the top of the screen. Nothing in the notification list either. The push arrived, and simply... vanished.

**This isn't a bug. It's the default behavior.** When your app is in the foreground, Firebase assumes *you* want to handle the message yourself, so it doesn't show anything. Instead, it hands the message to your code through `FirebaseMessaging.onMessage`, and if nobody is listening there, the message is gone.

Think of it like a mail carrier who sees you standing at the front door. They won't drop the letter in the mailbox. They hand it to you directly. And if you don't put your hand out... the letter falls on the ground.

#### Putting our hand out on Android

On Android, the fix is to listen to `onMessage` and show the notification **ourselves**, as a local notification. That's why `flutter_local_notifications` is on our list:

```dart
FirebaseMessaging.onMessage.listen(_showForegroundPush);
```

```dart
Future<void> _showForegroundPush(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  await _plugin.show(
    // Android notification ids must fit in a 32-bit int.
    id: message.messageId.hashCode & 0x7fffffff,
    title: notification.title,
    body: notification.body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _channel.id,
        _channel.name,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}
```

Let's break this down:
- We take the `title` and `body` from the push and show them as a local notification. To the user, it looks exactly like any other push.
- `Importance.high` on the channel is what makes Android show it as a **banner** at the top of the screen. With a lower importance, it would quietly go into the notification list and nobody would see it. (Channels were a whole section in the last article, if you want the full story.)
- The most important line is the last one: `payload: jsonEncode(message.data)`. A local notification can only carry a `String` payload, so we turn our `data` map into JSON. **This is how our `type` and `reference_id` survive the trip** from the push to the local notification.

#### And the tap?

The tap on that local notification goes through `flutter_local_notifications`, not Firebase. If you read the last article, this will look very familiar. We pass every tap into a stream:

```dart
await _plugin.initialize(
  settings: initializationSettings,
  onDidReceiveNotificationResponse: (response) => _taps.add(response.payload),
);
```

Then, on the other side, we decode the JSON back into a map, and hand it to the method that does the actual navigation:

```dart
void _handleLocalNotificationTap(String? payload) {
  if (payload == null) return;

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(payload) as Map<String, dynamic>;
  } catch (_) {
    return;
  }

  handleTap(data);
}
```

Hold on to that `handleTap(data)`. Every single scenario ends there, and we'll open it up in the next section.

#### What about iOS?

iOS is a bit nicer to us here. By default, it also hides pushes while the app is open, but we can simply ask it not to:

```dart
if (Platform.isIOS) {
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
  return;
}

FirebaseMessaging.onMessage.listen(_showForegroundPush);
```

With this one call, iOS shows its own native banner, and the tap comes back through Firebase, exactly like in Scenario 2. **That's also why we only show the local notification on Android.** If we did it on iOS too, the user would get the same notification twice.

So the app-open scenario needs two extra steps: catch the message, and show it yourself. **That's where we're going next:** the scenario that just works.

## Scenario 2: The app is in the background

This is the "easy" one. The user minimized your app, a push arrives, and this time **the OS shows it for you**. Your app doesn't even get involved. When the user taps it, the OS brings your app back to the front and Firebase lets you know:

```dart
FirebaseMessaging.onMessageOpenedApp.listen(
  (message) => handleTap(message.data),
);
```

That's it. One listener. `message.data` is the exact same map the server sent: our `type` and our `reference_id`.

Which means it's finally time to open `handleTap` and see where the user actually goes.

#### Where does the tap go?

```dart
Future<void> _navigate(Map<String, dynamic> data) async {
  final type = NotificationType.values.asNameMap()[data['type']];

  switch (type) {
    case NotificationType.live:
      _router.go(AppRoutes.live);
    case NotificationType.schedule:
      _router.go(AppRoutes.schedule);
    case NotificationType.article:
      final id = data['reference_id'] as String?;
      if (id == null) return;

      final article = await _articleRepository.getById(id);
      if (article == null) return;

      _router.push(AppRoutes.articleDetails, extra: article);
    case null:
      // Unknown type, e.g. sent to an older version of the app.
      return;
  }
}
```

There are a few small decisions in here, and each one has a reason.

**Why `asNameMap()` instead of `byName()`?** `NotificationType.values.byName('podcast')` throws if `podcast` doesn't exist. `asNameMap()['podcast']` just returns `null`. Remember the contract from earlier? The day your server sends a new type, older app versions land on `case null` and simply stay where they are. **No crash, no drama.**

**Why `go` for tabs, but `push` for the article?** `go` *replaces* where you are: the user jumps to the Live tab as if they'd tapped it themselves. `push` puts the article *on top* of the current screen. So when the user reads the article and presses back, they land inside your app, **not on their home screen**. Small detail, but you'll notice it immediately when it's wrong.

**Why fetch the article first?** The push only carries an id, but the details screen needs the whole article. So we fetch it, and only then navigate. And if it comes back `null` (maybe the article was deleted after the push was sent), we just don't navigate. Showing an empty screen would be worse than doing nothing.

#### Wait... where's the BuildContext?

You may have noticed: there is no `context` anywhere in this code. We call `_router.go(...)` directly on our `GoRouter` instance, which we pass into the handler when the app starts.

And that's not just a style choice, **it's a requirement.** A notification tap doesn't come from a button or any widget. There is no `context` to grab. If you want the full story on why navigating from outside the widget tree is a problem, I wrote [a whole article about it](https://dev.to/thanasistraitsis/the-context-behind-the-context-how-flutter-navigation-really-works-4j4). With go_router, you get it for free: the router object itself can navigate from anywhere.

So far so good. Two scenarios, one `handleTap`. But the third one is where most implementations quietly break.

## Scenario 3: The app is dead

The user swiped your app away hours ago. A push arrives, the OS shows it, the user taps it, and your app starts **from zero**. `main()` runs, Firebase initializes, the splash screen shows up...

In this case, `onMessageOpenedApp` never fires, because there was no app running to receive the event. Instead, you have to *ask* Firebase: *"Hey, was I launched by a notification?"*

```dart
final message = await FirebaseMessaging.instance.getInitialMessage();
```

If the answer is yes, you get the message. If the app was opened normally from the home screen, you get `null`.

> Quick myth-buster: `FirebaseMessaging.onBackgroundMessage` has **nothing** to do with taps. It's a handler that runs when a message *arrives* while your app is in the background or closed. If you're trying to handle a tap in there, that's why it isn't working.

So we have the message. We just navigate, right?

```dart
// ❌ Navigates while the app is still starting up
final message = await FirebaseMessaging.instance.getInitialMessage();
if (message != null) {
  router.go(AppRoutes.schedule);
}
```

**Well... not so fast.** Remember: the app is *just* starting. Most real apps don't show their main screens immediately. In ήτα.ρώ, the splash screen checks the internet connection, asks for notification permission on first launch, and checks if a force update is needed. In the sample app, the splash simply waits for the permission request and a short delay.

Here's how the app decides what to show:

```dart
return BlocBuilder<SplashCubit, SplashState>(
  builder: (context, state) => switch (state) {
    SplashLoading() => MaterialApp(home: const SplashScreen()),
    SplashReady() => MaterialApp.router(routerConfig: router),
  },
);
```

**While the splash is showing, the router isn't even on the screen.** And `getInitialMessage()` answers in milliseconds, long before the splash is done.

Now, what happens if you navigate at that moment depends on *how* you navigate. If you use a `GlobalKey<NavigatorState>` (like the NavigationService from my navigation article), `navigatorKey.currentState` is still `null`. The tap either crashes or silently disappears. go_router is more forgiving: I actually tested it, and it remembers the location and opens it once the router appears.

So with go_router we're fine, right? Not really. **The splash is where your app makes its decisions.** Is there an internet connection? Does the user have to update first? In other apps: is the user logged in, did they finish onboarding? A notification tap shouldn't be able to skip any of that. And the article we fetch on tap may depend on things that startup sets up, like a session or a config.

Think of it like a delivery that arrives at a shop before it opens. The delivery is real, the address is right, but the shop isn't ready. Maybe it's still being set up, maybe it won't open at all today. You don't throw the package inside through the window. **The courier waits at the door until the shop opens.**

#### Waiting at the door

That's exactly what `handleTap` does before navigating:

```dart
Future<void> handleTap(Map<String, dynamic> data) async {
  await _waitUntilAppReady();
  await _navigate(data);
}

Future<void> _waitUntilAppReady() {
  if (_splashCubit.state is SplashReady) return Future.value();
  return _splashCubit.stream.firstWhere((state) => state is SplashReady);
}
```

Our `SplashCubit` already knows when the app is ready. So we simply wait for it: `stream.firstWhere(...)` returns a `Future` that completes the moment the splash emits `SplashReady`. **The tap waits at the door, and walks in as soon as the shop opens.**

#### The line that's easy to forget

Look at the first line of `_waitUntilAppReady()` again:

```dart
if (_splashCubit.state is SplashReady) return Future.value();
```

Why do we need this? Because **a Cubit's stream doesn't replay its current state.** It only emits *future* changes. So if the app is already ready (which is the case for every tap in Scenarios 1 and 2!) and you only wait on the stream, you'll be waiting for a `SplashReady` that already happened. Forever.

Without that line, Scenario 3 works, and the other two silently stop working.

#### Why every tap goes through the door

You might be thinking: *"Fine, the dead app needs to wait. But why make the background and foreground taps wait too?"*

Two reasons. First, if the app is already ready, the wait costs nothing. It returns immediately. Second, "background" doesn't always mean "ready". The user can open your app, minimize it while it's still on the splash screen, and then tap a notification. Rare? Yes. But it costs us zero extra lines to handle it, because **every tap goes through the same door.**

#### What about local notifications in a dead app?

There's one more path into a dead app. Remember the local notification we showed in Scenario 1? If the user ignores it, closes the app, and taps it later, that's a *local* notification launching the app. Firebase knows nothing about it. That one is caught by `flutter_local_notifications` with `getNotificationAppLaunchDetails()`, which we covered in detail in the last article. It ends up in the same stream, goes through the same `handleTap`, and waits at the same door.

## Putting it all together

Here's the whole handler's entry point. Three states, three listeners:

```dart
void listen() {
  // App was dead: the tap is what launched it.
  _handleInitialMessage();

  // App was in the background: the tap brings it back.
  FirebaseMessaging.onMessageOpenedApp.listen(
    (message) => handleTap(message.data),
  );

  // App was open: we showed the push ourselves (Android).
  _localNotificationTaps.listen(_handleLocalNotificationTap);
}
```

And here's where it all gets wired up in `main()`:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notificationService = NotificationService();
  await notificationService.init();

  final articleRepository = ArticleRepository();
  final router = createRouter(articleRepository);
  final splashCubit = SplashCubit(
    prepare: notificationService.requestPermission,
  )..start();

  runApp(
    BlocProvider.value(value: splashCubit, child: App(router: router)),
  );

  PushTapHandler(
    router: router,
    splashCubit: splashCubit,
    articleRepository: articleRepository,
    localNotificationTaps: notificationService.onTap,
  ).listen();
}
```

Notice that the router and the splash cubit are created **outside** the widget tree. That's what lets the `PushTapHandler` use them without any `context`. And `listen()` is called right after `runApp()`, before the first frame is drawn, so no tap can slip through before we're listening.

If you want the whole picture in one place:

| App state | Who shows the notification | Who tells us about the tap |
| --- | --- | --- |
| **Open** | We do (Android) / iOS with presentation options | `onDidReceiveNotificationResponse` (Android) / `onMessageOpenedApp` (iOS) |
| **Background** | The OS | `onMessageOpenedApp` |
| **Dead** | The OS | `getInitialMessage()` |

**Three different doors into your app. One `handleTap` behind all of them.**

So much tapping...time to tap out.

![Tap out](https://github.com/Thanasis-Traitsis/flutter_tap_notifications/blob/main/assets/tap_out.gif)

## Conclusion

And there you have it! What started as *"just open the right screen when the user taps"* turned into three different paths, a mail carrier, and a courier waiting outside a closed shop.

So... what did we learn today? When the app is **open**, Firebase doesn't show anything, so on Android you show the push yourself, and on iOS you ask the system to show it. When the app is in the **background**, the OS does the work and `onMessageOpenedApp` tells you about the tap. And when the app is **dead**, you have to ask `getInitialMessage()`, and then wait until your app is actually ready to navigate.

But here's the bigger lesson. **A notification tap isn't a button press. It's a way into your app.** And like every way into your app, it has to respect your startup flow: the splash, the checks, the moment your screens actually exist. Once you see it like that, all three scenarios become the same simple idea: *wait until the app is ready, then go.*

One last thing. Notification taps are one way into a specific screen, but they aren't the only one. Links from a website or a shared message (app links on Android, universal links on iOS) face the exact same "the app isn't ready yet" problem. That's a story for another article.

If you enjoyed this article and want to stay connected, feel free to connect with me on [LinkedIn](https://www.linkedin.com/in/thanasis-traitsis/).

If you'd like to dive deeper into the code and contribute to the project, visit the repository on [GitHub](https://github.com/Thanasis-Traitsis/flutter_tap_notifications).

Was this guide helpful? Consider buying me a coffee!☕️ Your contribution goes a long way in fuelling future content and projects. [Buy Me a Coffee](https://www.buymeacoffee.com/thanasis_traitsis).

Now go ahead. Send yourself a few pushes, kill your app, tap them, and watch where you land. Happy coding, Flutter friends!
