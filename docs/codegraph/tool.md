# Code Graph — tool (2 files, 629 lines; generated 2026-10-01T07:59; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## tool/grapify.dart (388 lines)
- L12  function main
- L65  class GrapifyMember (name, line, isGetter) — GrapifyMember(this.name, this.line,…) L66
- L75  class GrapifySymbol (kind, name, line, parents, fields, members) — GrapifySymbol(this.kind, this.name, this.line,…) L76
- L87  function isGeneratedFile
- L93  function splitSourceLines
- L98  function layerOf
- L105  function extractSymbols
- L135  function renderFileSection
- L176  function _parseDeclaration
- L195  function _parents
- L278  function _signature
- L299  function _dartFiles
- L314  function _groupByLayer
- L325  function _relative
- L334  function _timestamp
- L342  function _formatCount
- L352  class _LayerSummary (layer, files, lines) — _LayerSummary(this.layer, this.files, this.lines) L353
- L360  function _readme
- L379  function change

## tool/smoke/windows_release_smoke.dart (241 lines)
- L15  function validateSmokeReport
- L40  function waitForSmokeReport
- L80  function runWindowsReleaseSmoke
- L142  function main
- L152  function _repositoryRoot
- L167  function _allocateReportPath
- L182  function _isRegularFile
- L191  function _isMissing
- L200  function _cleanupProcess
- L225  function _awaitSilently
- L233  function _deleteReport
