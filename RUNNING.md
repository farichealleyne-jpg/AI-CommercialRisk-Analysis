# Running the app on your own machine

Two things run at once: the **backend** (stores your data) and the **app** (what you
click on). Each needs its own terminal window, and both stay open while you use the app.

## One-time setup

Install these, in this order. Each has an installer you click through.

| What | Where | Check it worked |
| --- | --- | --- |
| Git | https://git-scm.com/download/win | `git --version` |
| Java (JDK 21 or newer) | https://www.oracle.com/java/technologies/downloads/ | `java -version` |
| Flutter | https://flutter.dev/docs/get-started/install | `flutter --version` |

"Check it worked" means: open a terminal (Windows key, type `cmd`, press Enter), type
that command, press Enter. A version number means it's installed. `'x' is not
recognized` means the installer finished but Windows can't find the program — the
program's folder needs adding to your PATH.

Then download the code, once:

```
cd Desktop
git clone https://github.com/farichealleyne-jpg/ai-commercialrisk-analysis.git
```

## Starting it up

### Terminal 1 — the backend

```
cd Desktop\ai-commercialrisk-analysis\backend
mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

Wait for a line saying **`Started CommercialServiceApplication`**. The first run takes
several minutes because it downloads its building blocks; later runs take seconds.

Leave this window open. Closing it stops the backend and the app stops working.

### Terminal 2 — the app

Open a **second** terminal (don't reuse the first):

```
cd Desktop\ai-commercialrisk-analysis\policysquare
flutter pub get
flutter run -d chrome
```

The app opens in a Chrome window.

### First time in the app

Create an account with the sign-up screen. The mobile number you enter is what your
properties, visits, and action items are filed under, so use the same one every time.

## Stopping

Press `Ctrl` + `C` in each terminal.

## Where your data lives

The `local` profile keeps everything in `backend/data/` on your own machine. It stays
there between restarts, and it is never uploaded — it is deliberately excluded from
Git. Deleting that folder erases every property, visit, and action you have entered.

Dropping `-Dspring-boot.run.profiles=local` switches the backend to PostgreSQL, which
is what a shared or hosted deployment would use. That needs a PostgreSQL server
installed and running; for a single person on one laptop it buys you nothing.

## When something goes wrong

**`'mvnw.cmd' is not recognized`** — you are in the wrong folder. The command only
works from inside the `backend` folder. Check with `cd` (it prints where you are).

**`'flutter' is not recognized`** — Flutter is installed but not on your PATH. Either
add its `bin` folder to PATH, or type the full path instead, for example
`C:\Users\Public\Desktop\flutter\bin\flutter run -d chrome`.

**Backend fails with a wall of compile errors mentioning `lombok`** — your JDK is
newer than the Lombok version the build resolves. Update to the latest Lombok by
bumping `<lombok.version>` in `backend/pom.xml`; if no release supports your JDK yet,
install JDK 21 (an LTS release) and build with that instead.

**App opens but everything is empty or errors** — the backend isn't running. Check
Terminal 1 for `Started CommercialServiceApplication`, and restart it if it exited.

**`Web server failed to start. Port 8081 is already in use`** — a backend is already
running from an earlier attempt. Either use that one, or close its terminal first.
