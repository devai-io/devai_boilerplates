// Stopwatch — start, stop, reset, and record lap times.
// The key idea: never count ticks. Ticks arrive late, so counting them drifts.
// Instead we remember WHEN we started (Date.now()) and subtract. Always accurate.

// 1) Grab the elements we need from the page.
const display = document.getElementById("display");
const startStopBtn = document.getElementById("startStop");
const lapBtn = document.getElementById("lap");
const resetBtn = document.getElementById("reset");
const lapList = document.getElementById("laps");

// 2) Our state. `elapsed` is time banked from earlier runs (ms). `startTime`
//    is the moment the current run began. `timer` holds the interval id, and
//    is also our "are we running?" flag (null means stopped).
let elapsed = 0;
let startTime = 0;
let timer = null;

// 3) Total milliseconds right now = banked time + how long this run has gone.
function currentTime() {
  return elapsed + (timer ? Date.now() - startTime : 0);
}

// 4) Turn milliseconds into mm:ss.cs (cs = hundredths of a second).
function format(ms) {
  const minutes = Math.floor(ms / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  const centis = Math.floor((ms % 1000) / 10);
  const pad = (n) => String(n).padStart(2, "0"); // 3 -> "03"
  return `${pad(minutes)}:${pad(seconds)}.${pad(centis)}`;
}

// 5) Repaint the big number from the current time.
function render() {
  display.textContent = format(currentTime());
}

// 6) One button starts or stops, depending on which state we're in.
function toggle() {
  if (timer) {
    // Stopping: bank this run into `elapsed`, then stop the ticker.
    elapsed = currentTime();
    clearInterval(timer);
    timer = null;
    startStopBtn.textContent = "Start";
  } else {
    // Starting: remember the moment, then repaint ~33 times a second so the
    // hundredths look smooth. The display is derived from Date.now(), not the
    // number of ticks, so a slow tick never makes the clock wrong.
    startTime = Date.now();
    timer = setInterval(render, 30);
    startStopBtn.textContent = "Stop";
  }
}

// 7) Reset everything back to zero and clear the lap list.
function reset() {
  clearInterval(timer);
  timer = null;
  elapsed = 0;
  startStopBtn.textContent = "Start";
  lapList.innerHTML = "";
  render();
}

// 8) Record a lap: add the current time as a new numbered <li>.
function addLap() {
  const item = document.createElement("li");
  item.textContent = format(currentTime());
  lapList.append(item);
}

startStopBtn.addEventListener("click", toggle);
lapBtn.addEventListener("click", addLap);
resetBtn.addEventListener("click", reset);

render(); // show 00:00.00 on load
