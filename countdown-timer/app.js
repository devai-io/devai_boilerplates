// Countdown Timer — every second, work out how far away a target time is and
// show the days / hours / minutes / seconds left. Stop the clock at zero.

// 1) Grab the elements we need.
const targetInput = document.getElementById("target");
const daysEl = document.getElementById("days");
const hoursEl = document.getElementById("hours");
const minutesEl = document.getElementById("minutes");
const secondsEl = document.getElementById("seconds");
const messageEl = document.getElementById("message");

// 2) `target` is the moment we're counting down to, stored as a Date.
//    Default to the next New Year so there's always something ticking.
function nextNewYear() {
  const year = new Date().getFullYear() + 1;
  return new Date(year, 0, 1, 0, 0, 0); // Jan 1st, midnight, next year
}
let target = nextNewYear();

// 3) `timer` holds the id that setInterval hands back, so we can stop it later.
let timer = null;

// 4) The "tick": this runs once every second. It compares now to the target,
//    updates the four numbers, and stops the clock once we hit zero.
function tick() {
  const now = new Date();
  const msLeft = target - now; // subtracting two Dates gives milliseconds apart

  if (msLeft <= 0) {
    daysEl.textContent = "0";
    hoursEl.textContent = "0";
    minutesEl.textContent = "0";
    secondsEl.textContent = "0";
    messageEl.textContent = "🎉 It's time!";
    clearInterval(timer); // stop calling tick — we're done
    return;
  }

  messageEl.textContent = "";

  // Turn the millisecond gap into whole days, hours, minutes, and seconds.
  const totalSeconds = Math.floor(msLeft / 1000);
  daysEl.textContent = Math.floor(totalSeconds / 86400); // 86400 seconds in a day
  hoursEl.textContent = Math.floor((totalSeconds % 86400) / 3600); // 3600 in an hour
  minutesEl.textContent = Math.floor((totalSeconds % 3600) / 60);
  secondsEl.textContent = totalSeconds % 60; // the leftover seconds
}

// 5) (Re)start the countdown. We clear any existing interval first so we never
//    end up with two timers running at the same time.
function start() {
  clearInterval(timer);
  tick(); // show a value right away instead of waiting a full second
  timer = setInterval(tick, 1000); // then run tick again every 1000 ms
}

// 6) When the user picks a date, count down to that instead. An empty or
//    invalid box gives an "Invalid Date", so we fall back to New Year.
targetInput.addEventListener("change", () => {
  const picked = new Date(targetInput.value);
  target = isNaN(picked.getTime()) ? nextNewYear() : picked;
  start();
});

// 7) Kick everything off.
start();
