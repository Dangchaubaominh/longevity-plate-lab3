import { readFileSync } from 'node:fs';
import { test, expect } from '@playwright/test';

test('production CSP permits Firebase Google loader and blocks an unrelated script',async({page})=>{
 const headers=readFileSync(new URL('../../public/_headers',import.meta.url),'utf8');
 const csp=headers.split(/\r?\n/).find(line=>line.trim().startsWith('Content-Security-Policy:'))!.trim().slice('Content-Security-Policy:'.length).trim();
 await page.route('**/csp-verification',route=>route.fulfill({contentType:'text/html',headers:{'Content-Security-Policy':csp},body:'<!doctype html><div id="google">pending</div><div id="unrelated">pending</div><script src="/csp-verification.js"></script>'}));
 await page.route('**/csp-verification.js',route=>route.fulfill({contentType:'application/javascript',body:`
  for(const [id,src] of [['google','https://apis.google.com/js/api.js'],['unrelated','https://unrelated-script.invalid/example.js']]){
   const script=document.createElement('script');script.src=src;
   script.onload=()=>{document.getElementById(id).textContent='loaded';};
   script.onerror=()=>{document.getElementById(id).textContent='blocked';};
   document.head.append(script);
  }
 `}));
 await page.route('https://apis.google.com/js/api.js',route=>route.fulfill({contentType:'application/javascript',body:'window.firebaseGoogleLoaderRequested=true;'}));
 await page.route('https://unrelated-script.invalid/example.js',route=>route.fulfill({contentType:'application/javascript',body:'window.unrelatedScriptExecuted=true;'}));
 await page.goto('/csp-verification');
 await expect(page.locator('#google')).toHaveText('loaded');
 await expect(page.locator('#unrelated')).toHaveText('blocked');
 expect(await page.evaluate(()=>Reflect.get(window,'unrelatedScriptExecuted'))).toBeUndefined();
 expect(csp).not.toContain("'unsafe-eval'");
});
