// SPORTS LIVE! 배포용 빌드: static/ → dist/
// 화면 스크립트는 난독화, CSS는 압축, 주석 제거. 원본(static/)은 그대로 두고 dist/만 사용자에게 나갑니다.
// Copyright (c) 2026 gustjrwjs. All rights reserved.
import fs from "node:fs";
import path from "node:path";
import JavaScriptObfuscator from "javascript-obfuscator";
import CleanCSS from "clean-css";

const SRC = "static", OUT = "dist";
const BANNER = "SPORTS LIVE! · Copyright (c) 2026 gustjrwjs. All rights reserved. 무단 복제·수정·배포 금지.";
fs.rmSync(OUT, {recursive:true, force:true});
fs.cpSync(SRC, OUT, {recursive:true});

let html = fs.readFileSync(path.join(SRC, "index.html"), "utf8");
const one = (re, what) => { const m = html.match(re); if (!m) throw new Error(what + " 을(를) 찾지 못했습니다"); return m; };

// 1) 스크립트: 배포 사이트엔 /espn 중계 서버가 없으니 바로 ESPN 직접 호출 → 난독화
const js = one(/<script>([\s\S]*?)<\/script>/, "스크립트");
let code = js[1];
const MODE0 = 'let MODE = location.protocol.startsWith("http") ? "server" : "direct";';
if (!code.includes(MODE0)) throw new Error("MODE 줄을 찾지 못했습니다");
code = code.replace(MODE0, 'let MODE = "direct";');
const ob = JavaScriptObfuscator.obfuscate(code, {
  target: "browser",
  compact: true,
  renameGlobals: false,            // 전역 이름은 유지(PiP 창 등에서 참조)
  identifierNamesGenerator: "hexadecimal",
  stringArray: true, stringArrayThreshold: 0.75, stringArrayRotate: true, stringArrayShuffle: true,
  stringArrayWrappersCount: 1, stringArrayEncoding: [],   // 속도 위해 문자열 인코딩은 생략
  splitStrings: false, controlFlowFlattening: false, deadCodeInjection: false,
  selfDefending: false, debugProtection: false, transformObjectKeys: false,
  unicodeEscapeSequence: false, simplify: true, sourceMap: false,
}).getObfuscatedCode();
html = html.replace(js[0], () => `<script>/* ${BANNER} */\n${ob}</script>`);

// 2) CSS 압축
const css = one(/<style>([\s\S]*?)<\/style>/, "스타일");
const mini = new CleanCSS({level:1}).minify(css[1]);
if (mini.errors.length) throw new Error("CSS: " + mini.errors.join(", "));
html = html.replace(css[0], () => `<style>${mini.styles}</style>`);

// 3) HTML 주석 제거 + 저작권 한 줄
html = html.replace(/<!--[\s\S]*?-->/g, "").replace(/<!doctype html>\s*/i, `<!doctype html>\n<!-- ${BANNER} -->\n`);
fs.writeFileSync(path.join(OUT, "index.html"), html);

// 4) 서비스 워커·매니페스트 주석 정리, Cloudflare 캐시 규칙
const sw = fs.readFileSync(path.join(SRC, "sw.js"), "utf8").replace(/^\s*\/\/.*$/gm, "").replace(/\n{2,}/g, "\n");
fs.writeFileSync(path.join(OUT, "sw.js"), `// ${BANNER}\n` + sw);
fs.writeFileSync(path.join(OUT, "_headers"), [
  "/*", "  X-Content-Type-Options: nosniff", "  Referrer-Policy: strict-origin-when-cross-origin",
  "/", "  Cache-Control: no-cache", "/index.html", "  Cache-Control: no-cache", "/sw.js", "  Cache-Control: no-cache", ""].join("\n"));
console.log(`빌드 완료: index.html ${(code.length / 1024).toFixed(0)}KB → ${(ob.length / 1024).toFixed(0)}KB (스크립트)`);
