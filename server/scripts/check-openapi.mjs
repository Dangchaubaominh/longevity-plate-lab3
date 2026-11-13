import { readFileSync } from "node:fs";
import assert from "node:assert/strict";
const spec = JSON.parse(readFileSync("../docs/openapi.json", "utf8"));
assert.match(spec.openapi, /^3\.1\./);
const ids = new Set();
let operations = 0;
for (const [path, item] of Object.entries(spec.paths))
  for (const [method, operation] of Object.entries(item)) {
    assert.ok(!ids.has(operation.operationId), "Duplicate operation ID");
    ids.add(operation.operationId);
    operations++;
    assert.ok(
      operation.responses["200"],
      `${method} ${path}: missing success response`,
    );
    const publicRoute = ["/health", "/api/public/config"].includes(path);
    assert.equal(
      operation.security.length,
      publicRoute ? 0 : 1,
      `${path}: authentication missing`,
    );
    for (const match of path.matchAll(/\{([^}]+)\}/g))
      assert.ok(
        operation.parameters.some(
          (p) => p.in === "path" && p.name === match[1] && p.required,
        ),
        `${path}: path parameter missing`,
      );
  }
function refs(value) {
  if (!value || typeof value !== "object") return;
  if (value.$ref) {
    assert.ok(value.$ref.startsWith("#/"));
    let target = spec;
    for (const key of value.$ref.slice(2).split("/")) target = target?.[key];
    assert.ok(target, `Unresolved ${value.$ref}`);
  }
  Object.values(value).forEach(refs);
}
refs(spec);
assert.equal(spec.components.schemas.push.properties.operations.maxItems, 5);
assert.ok(spec.paths["/api/v1/admin/push"].post.responses["201"]);
console.log(
  `OpenAPI structural checks passed: ${operations} operations, ${Object.keys(spec.paths).length} paths, all references resolve. Not a runtime cloud test.`,
);
