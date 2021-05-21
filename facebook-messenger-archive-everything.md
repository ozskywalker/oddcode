_forked from https://gist.github.com/tedmiston/c7ac401da96b55022aaf_

1. Load [Facebook Messenger](https://www.messenger.com) in a new tab.
2. Open the JavaScript console and paste the [contents of jquery.min.js](http://ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js) into the console. 
3. Run this code below in console:

```(function run() {
let all = document.querySelectorAll('div[aria-label="Menu"]');
if (all.length == 0) return;
let a = all[0];
a.click();
setTimeout(() => {
document.querySelectorAll('div[role=menuitem]').forEach(act => {
if (act.innerText.match(/Archive/)) act.click();
});
run();
}, 500);
})();
```

4. Wait until all messages are archived.  

Note, some 'special' messages may keep this script running forever - just keep an eye on it, and close the tab when it's done.  There's no intelligence here.  :)