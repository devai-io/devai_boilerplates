const display = document.getElementById("display");
const startStopBtn = document.getElementById("startStop");
const lapBtn = document.getElementById("lap");
const resetBtn = document.getElementById("reset");
const lapList = document.getElementById("laps");

// The key idea: never COUNT ticks. setInterval ticks arrive late and a busy or
// background tab skips them, so a counter drifts. Instead, remember WHEN this
// run started and subtract. performance.now() is a clock made for measuring:
// it only moves forward, even if the computer's date and time get adjusted.
let elapsed = 0; // ms banked from earlier runs, before the last Stop
let startTime = 0; // when the current run began
let timer = null; // the interval id; null means stopped

function currentTime() {
  return elapsed + (timer ? performance.now() - startTime : 0);
}

function format(ms) {
  const minutes = Math.floor(ms / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  const centis = Math.floor((ms % 1000) / 10);
  const pad = (n) => String(n).padStart(2, "0");
  return `${pad(minutes)}:${pad(seconds)}.${pad(centis)}`;
}

// The interval only decides how often we REPAINT. What we show always comes
// from currentTime(), so a slow tick can never make the clock wrong.
function render() {
  display.textContent = format(currentTime());
}

function toggle() {
  if (timer) {
    elapsed = currentTime();
    clearInterval(timer);
    timer = null;
    startStopBtn.textContent = "Start";
    render(); // show the exact stopping time, not the last repaint
  } else {
    startTime = performance.now();
    timer = setInterval(render, 30);
    startStopBtn.textContent = "Stop";
  }
}

function reset() {
  clearInterval(timer);
  timer = null;
  elapsed = 0;
  startStopBtn.textContent = "Start";
  lapList.replaceChildren();
  render();
}

function addLap() {
  const item = document.createElement("li");
  item.textContent = format(currentTime());
  lapList.append(item);
}

startStopBtn.addEventListener("click", toggle);
lapBtn.addEventListener("click", addLap);
resetBtn.addEventListener("click", reset);

render();
