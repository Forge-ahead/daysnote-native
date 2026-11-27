#!/usr/bin/env python3
"""生成 DaysNote.xcodeproj/project.pbxproj（SwiftUI App + WidgetKit Extension）"""
import os, uuid

ROOT = os.path.dirname(os.path.abspath(__file__))

def uid():
    return uuid.uuid4().hex.upper()[:24]

# 预分配 id
ids = {k: uid() for k in [
    'root','appGroup','widgetGroup','products','mainGroup','widgetGroupFolder',
    'appTarget','widgetTarget','appProduct','widgetProduct',
    'appBuildPhaseSources','appBuildPhaseFrameworks','appBuildPhaseResources',
    'widgetBuildPhaseSources','widgetBuildPhaseFrameworks','widgetBuildPhaseResources',
    'embedWidgets','appTargetDep','widgetTargetDep',
    'appInfo','appEntitlements','widgetInfo','widgetEntitlements','appIcon',
    'appBuildConfigList','appTargetConfigList','widgetTargetConfigList',
    'projDebug','projRelease','appDebug','appRelease','widgetDebug','widgetRelease',
]}

app_sources = [
    'DaysNoteApp.swift','Models.swift','DateUtils.swift','SyncEngine.swift',
    'Store.swift','HolidayService.swift','AIService.swift',
    'Views/Common.swift','Views/HomeView.swift','Views/TimelineView.swift',
    'Views/EventEditor.swift','Views/EventDetail.swift','Views/CategoryViews.swift',
    'Views/Drawer.swift','Views/TrashView.swift','Views/SettingsView.swift',
    'Views/WidgetsView.swift','Views/RootView.swift',
]
widget_sources = ['DaysNoteWidget.swift']

file_refs = {}
build_files = {}
for f in app_sources:
    file_refs[f] = uid(); build_files[f] = uid()
for f in widget_sources:
    file_refs[f] = uid(); build_files[f] = uid()

def pbproj():
    L = []
    a = L.append
    a('// !$*UTF8*$!')
    a('{')
    a('\tarchiveVersion = 1;')
    a('\tclasses = {')
    a('\t};')
    a('\tobjectVersion = 56;')
    a('\tobjects = {')

    # PBXProject
    a(f'\t\t{ids["root"]} /* Project object */ = {{')
    a('\t\t\tisa = PBXProject;')
    a('\t\t\tattributes = { BuildIndependentTargetsInParallel = 1; LastUpgradeCheck = 1600; };')
    a(f'\t\t\tbuildConfigurationList = {ids["appBuildConfigList"]} /* Build configuration list for PBXProject */;')
    a('\t\t\tcompatibilityVersion = "Xcode 14.0";')
    a('\t\t\tdevelopmentRegion = en;')
    a('\t\t\thasScannedForEncodings = 0;')
    a('\t\t\tknownRegions = ( en, Base, "zh-Hans" );')
    a(f'\t\t\tmainGroup = {ids["mainGroup"]};')
    a(f'\t\t\tproductRefGroup = {ids["products"]};')
    a('\t\t\tprojectDirPath = "";')
    a('\t\t\tprojectRoot = "";')
    a(f'\t\t\ttargets = ( {ids["appTarget"]} /* DaysNote */, {ids["widgetTarget"]} /* DaysNoteWidget */ );')
    a('\t\t};')

    # Groups
    a(f'\t\t{ids["mainGroup"]} = {{ isa = PBXGroup; children = ( {ids["appGroup"]}, {ids["widgetGroupFolder"]}, {ids["products"]} ); sourceTree = "<group>"; }};')
    # App group with subfolder Views
    views_group = uid()
    children = ' '.join(f'{file_refs[f]} /* {os.path.basename(f)} */' for f in app_sources if '/' not in f)
    a(f'\t\t{ids["appGroup"]} = {{ isa = PBXGroup; children = ( {children}, {views_group} /* Views */, {ids["appInfo"]} /* Info.plist */, {ids["appEntitlements"]} /* DaysNote.entitlements */, {ids["appIcon"]} /* Assets.xcassets */ ); path = DaysNote; sourceTree = "<group>"; }};')
    vchildren = ' '.join(f'{file_refs[f]} /* {os.path.basename(f)} */' for f in app_sources if '/' in f)
    a(f'\t\t{views_group} = {{ isa = PBXGroup; children = ( {vchildren} ); path = Views; sourceTree = "<group>"; }};')
    wchildren = ' '.join(f'{file_refs[f]} /* {os.path.basename(f)} */' for f in widget_sources)
    a(f'\t\t{ids["widgetGroupFolder"]} = {{ isa = PBXGroup; children = ( {wchildren}, {ids["widgetInfo"]} /* Info.plist */, {ids["widgetEntitlements"]} /* DaysNoteWidget.entitlements */ ); path = DaysNoteWidget; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["products"]} = {{ isa = PBXGroup; children = ( {ids["appProduct"]} /* DaysNote.app */, {ids["widgetProduct"]} /* DaysNoteWidget.appex */ ); name = Products; sourceTree = "<group>"; }};')

    # File refs
    for f, r in file_refs.items():
        name = os.path.basename(f)
        # 文件归属于 Views 子组，path 只写文件名（否则会拼成 Views/Views/xxx）
        a(f'\t\t{r} /* {name} */ = {{ isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{name}"; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["appInfo"]} /* Info.plist */ = {{ isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["appEntitlements"]} /* DaysNote.entitlements */ = {{ isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = DaysNote.entitlements; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["widgetInfo"]} /* Info.plist */ = {{ isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["widgetEntitlements"]} /* DaysNoteWidget.entitlements */ = {{ isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = DaysNoteWidget.entitlements; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["appIcon"]} /* Assets.xcassets */ = {{ isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
    a(f'\t\t{ids["appProduct"]} /* DaysNote.app */ = {{ isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = DaysNote.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    a(f'\t\t{ids["widgetProduct"]} /* DaysNoteWidget.appex */ = {{ isa = PBXFileReference; explicitFileType = wrapper.app-extension; includeInIndex = 0; path = DaysNoteWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};')

    # Build files
    for f, b in build_files.items():
        a(f'\t\t{b} /* {os.path.basename(f)} in Sources */ = {{ isa = PBXBuildFile; fileRef = {file_refs[f]} /* {os.path.basename(f)} */; }};')
    for k in ['appInfo','appEntitlements','widgetInfo','widgetEntitlements','appIcon']:
        a(f'\t\t{uid()} /* placeholder */ = {{ isa = PBXBuildFile; fileRef = {ids[k]}; }};') if False else None
    icon_bf = uid()
    a(f'\t\t{icon_bf} /* Assets.xcassets in Resources */ = {{ isa = PBXBuildFile; fileRef = {ids["appIcon"]} /* Assets.xcassets */; }};')

    # Targets
    a(f'\t\t{ids["appTarget"]} /* DaysNote */ = {{')
    a('\t\t\tisa = PBXNativeTarget;')
    a(f'\t\t\tbuildConfigurationList = {ids["appTargetConfigList"]};')
    a(f'\t\t\tbuildPhases = ( {ids["appBuildPhaseSources"]}, {ids["appBuildPhaseFrameworks"]}, {ids["appBuildPhaseResources"]}, {ids["embedWidgets"]} );')
    a('\t\t\tbuildRules = ( );')
    a(f'\t\t\tdependencies = ( {ids["appTargetDep"]} );')
    a('\t\t\tname = DaysNote;')
    a(f'\t\t\tproductName = DaysNote;')
    a(f'\t\t\tproductReference = {ids["appProduct"]} /* DaysNote.app */;')
    a('\t\t\tproductType = "com.apple.product-type.application";')
    a('\t\t};')
    a(f'\t\t{ids["widgetTarget"]} /* DaysNoteWidget */ = {{')
    a('\t\t\tisa = PBXNativeTarget;')
    a(f'\t\t\tbuildConfigurationList = {ids["widgetTargetConfigList"]};')
    a(f'\t\t\tbuildPhases = ( {ids["widgetBuildPhaseSources"]}, {ids["widgetBuildPhaseFrameworks"]}, {ids["widgetBuildPhaseResources"]} );')
    a('\t\t\tbuildRules = ( );')
    a('\t\t\tdependencies = ( );')
    a('\t\t\tname = DaysNoteWidget;')
    a(f'\t\t\tproductName = DaysNoteWidget;')
    a(f'\t\t\tproductReference = {ids["widgetProduct"]} /* DaysNoteWidget.appex */;')
    a('\t\t\tproductType = "com.apple.product-type.app-extension";')
    a('\t\t};')

    # Target dependency
    proxy_id = uid()
    a(f'\t\t{ids["appTargetDep"]} /* PBXTargetDependency */ = {{')
    a('\t\t\tisa = PBXTargetDependency;')
    a(f'\t\t\ttarget = {ids["widgetTarget"]} /* DaysNoteWidget */;')
    a(f'\t\t\ttargetProxy = {proxy_id} /* PBXContainerItemProxy */;')
    a('\t\t};')
    a(f'\t\t{proxy_id} /* PBXContainerItemProxy */ = {{')
    a('\t\t\tisa = PBXContainerItemProxy;')
    a(f'\t\t\tcontainerPortal = {ids["root"]} /* Project object */;')
    a('\t\t\tproxyType = 1;')
    a(f'\t\t\tremoteGlobalIDString = {ids["widgetTarget"]};')
    a('\t\t\tremoteInfo = DaysNoteWidget;')
    a('\t\t};')

    # Build phases
    app_src = ' '.join(f'{build_files[f]} /* {os.path.basename(f)} in Sources */' for f in app_sources if '/' not in f)
    # Views files are in a group but still need build files; already created
    app_src_all = ' '.join(f'{build_files[f]} /* {os.path.basename(f)} in Sources */' for f in app_sources)
    a(f'\t\t{ids["appBuildPhaseSources"]} /* Sources */ = {{ isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( {app_src_all} ); runOnlyForDeploymentPostprocessing = 0; }};')
    a(f'\t\t{ids["appBuildPhaseFrameworks"]} /* Frameworks */ = {{ isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }};')
    a(f'\t\t{ids["appBuildPhaseResources"]} /* Resources */ = {{ isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( {icon_bf} /* Assets.xcassets in Resources */ ); runOnlyForDeploymentPostprocessing = 0; }};')
    w_src_all = ' '.join(f'{build_files[f]} /* {os.path.basename(f)} in Sources */' for f in widget_sources)
    a(f'\t\t{ids["widgetBuildPhaseSources"]} /* Sources */ = {{ isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ( {w_src_all} ); runOnlyForDeploymentPostprocessing = 0; }};')
    a(f'\t\t{ids["widgetBuildPhaseFrameworks"]} /* Frameworks */ = {{ isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }};')
    a(f'\t\t{ids["widgetBuildPhaseResources"]} /* Resources */ = {{ isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( ); runOnlyForDeploymentPostprocessing = 0; }};')
    # Embed App Extensions
    embed_bf = uid()
    a(f'\t\t{ids["embedWidgets"]} /* Embed App Extensions */ = {{')
    a('\t\t\tisa = PBXCopyFilesBuildPhase;')
    a('\t\t\tbuildActionMask = 2147483647;')
    a('\t\t\tdstPath = "";')
    a('\t\t\tdstSubfolderSpec = 13;')
    a(f'\t\t\tfiles = ( {embed_bf} /* DaysNoteWidget.appex in Embed App Extensions */ );')
    a('\t\t\tname = "Embed App Extensions";')
    a('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
    a('\t\t};')
    a(f'\t\t{embed_bf} /* DaysNoteWidget.appex in Embed App Extensions */ = {{ isa = PBXBuildFile; fileRef = {ids["widgetProduct"]} /* DaysNoteWidget.appex */; settings = {{ ATTRIBUTES = ( RemoveHeadersOnCopy, ); }}; }};')

    # Config lists
    a(f'\t\t{ids["appBuildConfigList"]} = {{')
    a('\t\t\tisa = XCConfigurationList;')
    a(f'\t\t\tbuildConfigurations = ( {ids["projDebug"]}, {ids["projRelease"]} );')
    a('\t\t\tdefaultConfigurationIsVisible = 0;')
    a('\t\t\tdefaultConfigurationName = Release;')
    a('\t\t};')
    a(f'\t\t{ids["appTargetConfigList"]} = {{')
    a('\t\t\tisa = XCConfigurationList;')
    a(f'\t\t\tbuildConfigurations = ( {ids["appDebug"]}, {ids["appRelease"]} );')
    a('\t\t\tdefaultConfigurationIsVisible = 0;')
    a('\t\t\tdefaultConfigurationName = Release;')
    a('\t\t};')
    a(f'\t\t{ids["widgetTargetConfigList"]} = {{')
    a('\t\t\tisa = XCConfigurationList;')
    a(f'\t\t\tbuildConfigurations = ( {ids["widgetDebug"]}, {ids["widgetRelease"]} );')
    a('\t\t\tdefaultConfigurationIsVisible = 0;')
    a('\t\t\tdefaultConfigurationName = Release;')
    a('\t\t};')

    # Build configurations
    common = [
        ('CLANG_ANALYZER_NONNULL','YES'),('CLANG_ENABLE_MODULES','YES'),
        ('CLANG_ENABLE_OBJC_ARC','YES'),('COPY_PHASE_STRIP','NO'),
        ('ENABLE_STRICT_OBJC_MSGSEND','YES'),('GCC_C_LANGUAGE_STANDARD','gnu17'),
        ('IPHONEOS_DEPLOYMENT_TARGET','17.0'),('SDKROOT','iphoneos'),
        ('SWIFT_VERSION','5.0'),('TARGETED_DEVICE_FAMILY','1,2'),
        ('MARKETING_VERSION','3.0.0'),('CURRENT_PROJECT_VERSION','31'),
    ]
    debug = common + [
        ('DEBUG_INFORMATION_FORMAT','dwarf'),('ENABLE_TESTABILITY','YES'),
        ('GCC_OPTIMIZATION_LEVEL','0'),('GCC_PREPROCESSOR_DEFINITIONS','DEBUG=1'),
        ('ONLY_ACTIVE_ARCH','YES'),('SWIFT_OPTIMIZATION_LEVEL','-Onone'),
    ]
    release = common + [
        ('DEBUG_INFORMATION_FORMAT','dwarf-with-dsym'),
        ('ENABLE_NS_ASSERTIONS','NO'),('SWIFT_COMPILATION_MODE','wholemodule'),
        ('SWIFT_OPTIMIZATION_LEVEL','-O'),('VALIDATE_PRODUCT','YES'),
    ]

    def cfg(cid, name, pairs, is_proj=False, is_app=False, is_widget=False):
        a(f'\t\t{cid} /* {name} */ = {{')
        a('\t\t\tisa = XCBuildConfiguration;')
        if is_proj:
            a(f'\t\t\tbuildSettings = {{ ALWAYS_SEARCH_USER_PATHS = NO; SDKROOT = iphoneos; IPHONEOS_DEPLOYMENT_TARGET = 17.0; SWIFT_VERSION = 5.0; }};')
        else:
            a('\t\t\tbuildSettings = {')
            for k,v in pairs:
                a(f'\t\t\t\t{k} = {v};')
            if is_app:
                a('\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;')
                a('\t\t\t\tCODE_SIGN_ENTITLEMENTS = DaysNote/DaysNote.entitlements;')
                a('\t\t\t\tCURRENT_PROJECT_VERSION = 31;')
                a('\t\t\t\tINFOPLIST_FILE = DaysNote/Info.plist;')
                a('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ( "$(inherited)", "@executable_path/Frameworks" );')
                a('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.daysnote.app;')
                a('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
                a('\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;')
            if is_widget:
                a('\t\t\t\tCODE_SIGN_ENTITLEMENTS = DaysNoteWidget/DaysNoteWidget.entitlements;')
                a('\t\t\t\tCURRENT_PROJECT_VERSION = 31;')
                a('\t\t\t\tINFOPLIST_FILE = DaysNoteWidget/Info.plist;')
                a('\t\t\t\tLD_RUNPATH_SEARCH_PATHS = ( "$(inherited)", "@executable_path/Frameworks", "@executable_path/../../Frameworks" );')
                a('\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.daysnote.app.DaysNoteWidget;')
                a('\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";')
                a('\t\t\t\tSKIP_INSTALL = YES;')
            a('\t\t\t};')
        a(f'\t\t\tname = {name};')
        a('\t\t};')

    cfg(ids['projDebug'],'Debug',debug,is_proj=True)
    cfg(ids['projRelease'],'Release',release,is_proj=True)
    cfg(ids['appDebug'],'Debug',debug,is_app=True)
    cfg(ids['appRelease'],'Release',release,is_app=True)
    cfg(ids['widgetDebug'],'Debug',debug,is_widget=True)
    cfg(ids['widgetRelease'],'Release',release,is_widget=True)

    a('\t};')
    a('\trootObject = ' + ids['root'] + ' /* Project object */;')
    a('}')
    return '\n'.join(L)

os.makedirs(os.path.join(ROOT,'DaysNote.xcodeproj'), exist_ok=True)
open(os.path.join(ROOT,'DaysNote.xcodeproj','project.pbxproj'),'w').write(pbproj())
print('project.pbxproj generated')
