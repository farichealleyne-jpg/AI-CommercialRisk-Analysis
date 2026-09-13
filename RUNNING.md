# Running the app on your own machine

The backend serves the app as well as the data, so running it is one command in one
terminal. **You do not need Flutter installed** — a compiled copy of the app lives in
`backend/src/main/resources/static/` and is served automatically.

## One-time setup

| What | Where | Check it worked |
| --- | --- | --- |
| Git | https://git-scm.com/download/win | `git --version` |
| Java **JDK 21** (see note) | https://www.oracle.com/java/technologies/downloads/ | `java -version` |

**Use JDK 21 specifically, not the newest Java.** The build depends on Lombok, which
hooks into compiler internals and therefore has to be updated for each new JDK. On
JDK 26 it silently generates nothing and the build dies with dozens of `variable X not
initialized in the default constructor` errors. JDK 21 is a long-term-support release
and is what this project targets. Pick the **JDK 21** tab on the Oracle download page.

If you already installed a newer JDK, you do not have to remove it — install 21 as
well and point `JAVA_HOME` at it (see *When something goes wrong* below).

"Check it worked" means: open a terminal (Windows key, type `cmd`, press Enter), type
that command, press Enter. A version number means it's installed.

Then download the code, once:

```
git clone https://github.com/farichealleyne-jpg/ai-commercialrisk-analysis.git
```

## Starting it up

```
cd ai-commercialrisk-analysis\backend
mvnw.cmd spring-boot:run -Dspring-boot.run.profiles=local
```

Wait for a line saying **`Started CommercialServiceApplication`**. The first run takes
several minutes because it downloads its building blocks; later runs take seconds.

Then open **http://localhost:8081** in your browser.

Leave the terminal open — closing it stops the app. Press `Ctrl` + `C` to stop.

### First time in

Create an account on the sign-up screen. The mobile number you enter is what your
properties, visits, and action items are filed under, so use the same one every time.

## Where your data lives

The `local` profile keeps everything in `backend/data/` on your own machine. It stays
there between restarts, and is never uploaded — it is deliberately excluded from Git.
Deleting that folder erases every property, visit, and action you have entered.

Dropping `-Dspring-boot.run.profiles=local` switches the backend to PostgreSQL, which
is what a shared or hosted deployment would use. That needs a PostgreSQL server
installed and running; for a single person on one laptop it buys you nothing.

## Changing the app's screens

Only needed if you want to alter the interface itself — not for day-to-day use.

Editing files under `policysquare/lib/` changes nothing on its own, because the
backend serves the **compiled** copy. After editing, rebuild and reinstall it:

```
cd policysquare
flutter build web --release --no-web-resources-cdn
```

then replace `backend/src/main/resources/static/` with the contents of
`policysquare/build/web/`, and restart the backend.

`--no-web-resources-cdn` matters: without it the compiled app fetches its graphics
engine from a Google CDN at runtime, and the page renders blank wherever that CDN is
slow or unreachable. With it, everything is served from your own machine.

For live reload while editing screens, `flutter run -d chrome` is faster — but it
needs a working Flutter install, which the compiled bundle exists to avoid.

## When something goes wrong

**`'mvnw.cmd' is not recognized`** — you are in the wrong folder. The command only
works from inside the `backend` folder. Check with `cd` (it prints where you are).

**`variable <something> not initialized in the default constructor`, many times over**
— you are building on a JDK that Lombok does not support yet, so the constructors it
normally writes for you were never generated. Build on JDK 21 instead.

To use JDK 21 while a newer JDK stays installed, set `JAVA_HOME` to the JDK 21 folder
(typically `C:\Program Files\Java\jdk-21`): Windows key → search *Environment
Variables* → **Edit the system environment variables** → **Environment Variables** →
under *User variables* click **New** → name `JAVA_HOME`, value that folder path. Open
a **new** terminal afterwards; Maven reads `JAVA_HOME` in preference to your PATH.
Confirm with `mvnw.cmd -version`, which prints the JDK it will actually use.

**`Web server failed to start. Port 8081 is already in use`** — a backend is already
running from an earlier attempt. Either use that one, or close its terminal first.

**Browser shows a blank white page** — the app crashed during startup. Open the
browser's developer console (F12) and read the first error; a blank page with no
console error usually means the page is still loading its graphics engine.
