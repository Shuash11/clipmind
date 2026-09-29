# Code Graph — tool (2 files, 625 lines; generated 2026-09-29T15:29; DO NOT EDIT)
_Generated files (*.g.dart, *.freezed.dart) excluded. Relationships are extends/implements/with hints + member line refs — navigate, then read the file for details._

## tool/grapify.dart (384 lines)
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
- L274  function _signature
- L295  function _dartFiles
- L310  function _groupByLayer
- L321  function _relative
- L330  function _timestamp
- L338  function _formatCount
- L348  class _LayerSummary (layer, files, lines) — _LayerSummary(this.layer, this.files, this.lines) L349
- L356  function _readme
- L375  function change

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
