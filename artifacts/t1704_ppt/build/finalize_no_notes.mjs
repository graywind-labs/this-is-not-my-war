import {pathToFileURL} from 'node:url';
const base='D:/这不是我的战争/artifacts/t1704_ppt';
const skill='C:/Users/JT/.codex/plugins/cache/openai-primary-runtime/presentations/26.909.12148/skills/presentations';
const rev='final_no_notes';
const candidate=base+'/build/final_no_notes_candidate.pptx';
const {finalizePresentation}=await import(pathToFileURL(skill+'/container_tools/artifact_tool_utils.mjs').href);
const result=await finalizePresentation({workspaceDir:base,candidatePath:candidate,finalPath:`${base}/output/这不是我的战争-游戏作品介绍Deck.pptx`,pythonExecutable:'C:/Users/JT/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe',integrityValidatorPath:skill+'/container_tools/inspect_presentation_package_integrity.py',layoutValidatorPath:skill+'/container_tools/inspect_presentation_layout_geometry.py',layoutArgs:['--expected-slide-size-emu','12192000,6858000','--validate-heading-fit'],explicitTotalSlideCount:19,requiredNativeChartOwnerSlides:[],requiredNativeTableOwnerSlides:[],verifyArtifactToolImport:true,receiptPath:`${base}/build/${rev}_validation.json`});
console.log(JSON.stringify({final:result.finalPath,integrity:result.packageIntegrity?.status}));
