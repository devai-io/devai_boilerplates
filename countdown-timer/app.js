const targetInput = document.getElementById("target");
const daysEl = document.getElementById("days");
const hoursEl = document.getElementById("hours");
const minutesEl = document.getElementById("minutes");
const secondsEl = document.getElementById("seconds");
const messageEl = document.getElementById("message");

function nextNewYear() {
  return new Date(new Date().getFullYear() + 1, 0, 1); // Jan 1st, midnight
}
let target = nextNewYear();

// setInterval hands back an id. We keep it so clearInterval can stop the clock.
let timer = null;

// tick() runs once a second. Subtracting two Dates gives the milliseconds
// between them; the rest is dividing that gap into days, hours, minutes, seconds.
function tick() {
  const msLeft = target - new Date();

  if (msLeft <= 0) {
    daysEl.textContent = hoursEl.textContent = minutesEl.textContent = secondsEl.textContent = "0";
    messageEl.textContent = "🎉 It's time!";
    clearInterval(timer); // we're done — stop calling tick()
    return;
  }

  messageEl.textContent = "";
  const totalSeconds = Math.floor(msLeft / 1000);
  daysEl.textContent = Math.floor(totalSeconds / 86400); // 86,400 seconds in a day
  hoursEl.textContent = Math.floor((totalSeconds % 86400) / 3600);
  minutesEl.textContent = Math.floor((totalSeconds % 3600) / 60);
  secondsEl.textContent = totalSeconds % 60;
}

// Always clear the old interval before starting a new one — otherwise every
// date change would stack up another timer, all running at once.
function start() {
  clearInterval(timer);
  tick(); // show a value now instead of waiting a full second
  timer = setInterval(tick, 1000);
}

targetInput.addEventListener("change", () => {
  const picked = new Date(targetInput.value);
  target = isNaN(picked.getTime()) ? nextNewYear() : picked; // empty box → New Year
  start();
});

start();
