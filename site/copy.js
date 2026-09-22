// Copy button for the install one-liner. No network access, no storage.
document.addEventListener('DOMContentLoaded', function () {
  var btn = document.getElementById('copy-btn');
  var code = document.getElementById('install-cmd');
  var status = document.getElementById('copy-status');
  if (!btn || !code || !status) return;
  var timer = null;

  function show(msg) {
    status.textContent = msg;
    clearTimeout(timer);
    timer = setTimeout(function () { status.textContent = ''; }, 2000);
  }

  function selectFallback() {
    var range = document.createRange();
    range.selectNodeContents(code);
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    show('Press ⌘C to copy');
  }

  btn.hidden = false;
  btn.addEventListener('click', function () {
    if (!navigator.clipboard || !navigator.clipboard.writeText) { selectFallback(); return; }
    navigator.clipboard.writeText(code.textContent).then(
      function () { show('Copied'); },
      selectFallback
    );
  });
});
