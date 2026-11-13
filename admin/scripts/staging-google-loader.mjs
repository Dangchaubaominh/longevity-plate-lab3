// Read-only browser verification of the deployed CSP + real Firebase loader.
// Does not enter credentials or claim that a Google user signed in.
import {chromium} from 'playwright';
import {mkdirSync,writeFileSync} from 'node:fs';
const browser=await chromium.launch({headless:true});
const page=await browser.newPage();let googleCspBlocks=0;
page.on('console',message=>{if(message.type()==='error'&&/content security policy|violates.*policy/i.test(message.text())&&/apis\.google\.com/.test(message.text()))googleCspBlocks++;});
const report={time:new Date().toISOString(),url:'https://longevity-plate-lab3-staging.longevity-plate-dai05.workers.dev',googleCspBlocks:0};
try{
 await page.goto(report.url,{waitUntil:'networkidle'});
 const button=page.getByRole('button',{name:'Tiếp tục với Google'});await button.waitFor();
 const script=page.waitForResponse(response=>response.url().startsWith('https://apis.google.com/js/api.js'),{timeout:25000}).catch(()=>null);
 const popup=page.waitForEvent('popup',{timeout:25000}).catch(()=>null);
 await button.click();const [loaded,opened]=await Promise.all([script,popup]);
 report.googleLoaderStatus=loaded?.status()??null;
 if(opened){await opened.waitForURL(url=>url.hostname==='accounts.google.com',{timeout:25000}).catch(()=>{});report.popupHost=new URL(opened.url()).hostname;}
 report.googleCspBlocks=googleCspBlocks;
 report.pass=report.googleLoaderStatus===200&&report.popupHost==='accounts.google.com'&&googleCspBlocks===0;
 mkdirSync('../artifacts/backend-implementation',{recursive:true});
 await page.screenshot({path:'../artifacts/backend-implementation/staging-google-login.png',fullPage:true});
 console.log(JSON.stringify(report));
}catch{report.pass=false;console.log('Deployed Google loader verification failed; private browser data omitted.');}
finally{writeFileSync('../artifacts/backend-implementation/staging-google-loader.json',JSON.stringify(report,null,2)+'\n');await browser.close();}
if(!report.pass)process.exitCode=1;
