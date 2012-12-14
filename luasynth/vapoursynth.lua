if jit.os == "Windows" then
  return [[
typedef struct VSFrameRef VSFrameRef;
typedef struct VSNodeRef VSNodeRef;
typedef struct VSCore VSCore;
typedef struct VSPlugin VSPlugin;
typedef struct VSNode VSNode;
typedef struct VSFuncRef VSFuncRef;
typedef struct VSMap VSMap;
typedef struct VSAPI VSAPI;
typedef struct VSFrameContext VSFrameContext;

typedef enum VSColorFamily {

    cmGray   = 1000000,
    cmRGB    = 2000000,
    cmYUV    = 3000000,
    cmYCoCg  = 4000000,

    cmCompat = 9000000
} VSColorFamily;

typedef enum VSSampleType {
    stInteger = 0,
    stFloat = 1
} VSSampleType;


typedef enum VSPresetFormat {
    pfNone = 0,

    pfGray8 = cmGray + 10,
    pfGray16,

    pfGrayH,
    pfGrayS,

    pfYUV420P8 = cmYUV + 10,
    pfYUV422P8,
    pfYUV444P8,
    pfYUV410P8,
    pfYUV411P8,
    pfYUV440P8,

    pfYUV420P9,
    pfYUV422P9,
    pfYUV444P9,

    pfYUV420P10,
    pfYUV422P10,
    pfYUV444P10,

    pfYUV420P16,
    pfYUV422P16,
    pfYUV444P16,

    pfYUV444PH,
    pfYUV444PS,

    pfRGB24 = cmRGB + 10,
    pfRGB27,
    pfRGB30,
    pfRGB48,

    pfRGBH,
    pfRGBS,



    pfCompatBGR32 = cmCompat + 10,
    pfCompatYUY2
} VSPresetFormat;

typedef enum VSFilterMode {
    fmParallel = 100,
    fmParallelRequests = 200,
    fmUnordered = 300,
    fmSerial = 400
} VSFilterMode;

typedef struct VSFormat {
    char name[32];
    int id;
    int colorFamily;
    int sampleType;
    int bitsPerSample;
    int bytesPerSample;

    int subSamplingW;
    int subSamplingH;

    int numPlanes;
} VSFormat;

typedef enum NodeFlags {
    nfNoCache = 1,
} NodeFlags;

typedef enum GetPropErrors {
    peUnset = 1,
    peType  = 2,
    peIndex = 4
} GetPropErrors;

typedef enum PropAppendMode {
    paReplace = 0,
    paAppend  = 1,
    paTouch   = 2
} PropAppendMode;

typedef struct VSCoreInfo {
    const char *versionString;
    int core;
    int api;
    int numThreads;
    int64_t maxFramebufferSize;
    int64_t usedFramebufferSize;
} VSCoreInfo;

typedef struct VSVideoInfo {
    const VSFormat *format;
    int64_t fpsNum;
    int64_t fpsDen;
    int width;
    int height;
    int numFrames;
    int flags;
} VSVideoInfo;

typedef enum ActivationReason {
    arInitial = 0,
    arFrameReady = 1,
    arAllFramesReady = 2,
    arError = -1
} ActivationReason;


typedef	VSCore *(__stdcall *VSCreateCore)(int threads);
typedef	void (__stdcall *VSFreeCore)(VSCore *core);
typedef const VSCoreInfo *(__stdcall *VSGetCoreInfo)(VSCore *core);


typedef void (__stdcall *VSPublicFunction)(const VSMap *in, VSMap *out, void *userData, VSCore *core, const VSAPI *vsapi);
typedef void (__stdcall *VSFreeFuncData)(void *userData);
typedef void (__stdcall *VSFilterInit)(VSMap *in, VSMap *out, void **instanceData, VSNode *node, VSCore *core, const VSAPI *vsapi);
typedef const VSFrameRef *(__stdcall *VSFilterGetFrame)(int n, int activationReason, void **instanceData, void **frameData, VSFrameContext *frameCtx, VSCore *core, const VSAPI *vsapi);
typedef int (__stdcall *VSGetOutputIndex)(VSFrameContext *frameCtx);
typedef void (__stdcall *VSFilterFree)(void *instanceData, VSCore *core, const VSAPI *vsapi);
typedef void (__stdcall *VSRegisterFunction)(const char *name, const char *args, VSPublicFunction argsFunc, void *functionData, VSPlugin *plugin);
typedef void (__stdcall *VSCreateFilter)(const VSMap *in, VSMap *out, const char *name, VSFilterInit init, VSFilterGetFrame getFrame, VSFilterFree free, int filterMode, int flags, void *instanceData, VSCore *core);
typedef VSMap *(__stdcall *VSInvoke)(VSPlugin *plugin, const char *name, const VSMap *args);
typedef void (__stdcall *VSSetError)(VSMap *map, const char *errorMessage);
typedef const char *(__stdcall *VSGetError)(const VSMap *map);
typedef void (__stdcall *VSSetFilterError)(const char *errorMessage, VSFrameContext *frameCtx);

typedef const VSFormat *(__stdcall *VSGetFormatPreset)(int id, VSCore *core);
typedef const VSFormat *(__stdcall *VSRegisterFormat)(int colorFamily, int sampleType, int bitsPerSample, int subSamplingW, int subSamplingH, VSCore *core);


typedef void (__stdcall *VSFrameDoneCallback)(void *userData, const VSFrameRef *f, int n, VSNodeRef *, const char *errorMsg);
typedef void (__stdcall *VSGetFrameAsync)(int n, VSNodeRef *node, VSFrameDoneCallback callback, void *userData);
typedef const VSFrameRef *(__stdcall *VSGetFrame)(int n, VSNodeRef *node, char *errorMsg, int bufSize);
typedef void (__stdcall *VSRequestFrameFilter)(int n, VSNodeRef *node, VSFrameContext *frameCtx);
typedef const VSFrameRef *(__stdcall *VSGetFrameFilter)(int n, VSNodeRef *node, VSFrameContext *frameCtx);
typedef const VSFrameRef *(__stdcall *VSCloneFrameRef)(const VSFrameRef *f);
typedef VSNodeRef *(__stdcall *VSCloneNodeRef)(VSNodeRef *node);
typedef VSFuncRef *(__stdcall *VSCloneFuncRef)(VSFuncRef *f);
typedef void (__stdcall *VSFreeFrame)(const VSFrameRef *f);
typedef void (__stdcall *VSFreeNode)(VSNodeRef *node);
typedef void (__stdcall *VSFreeFunc)(VSFuncRef *f);
typedef VSFrameRef *(__stdcall *VSNewVideoFrame)(const VSFormat *format, int width, int height, const VSFrameRef *propSrc, VSCore *core);
typedef VSFrameRef *(__stdcall *VSNewVideoFrame2)(const VSFormat *format, int width, int height, const VSFrameRef **planeSrc, const int *planes, const VSFrameRef *propSrc, VSCore *core);
typedef VSFrameRef *(__stdcall *VSCopyFrame)(const VSFrameRef *f, VSCore *core);
typedef void (__stdcall *VSCopyFrameProps)(const VSFrameRef *src, VSFrameRef *dst, VSCore *core);
typedef int (__stdcall *VSGetStride)(const VSFrameRef *f, int plane);
typedef const uint8_t *(__stdcall *VSGetReadPtr)(const VSFrameRef *f, int plane);
typedef uint8_t *(__stdcall *VSGetWritePtr)(VSFrameRef *f, int plane);


typedef const VSVideoInfo *(__stdcall *VSGetVideoInfo)(VSNodeRef *node);
typedef void (__stdcall *VSSetVideoInfo)(const VSVideoInfo *vi, int numOutputs, VSNode *node);
typedef const VSFormat *(__stdcall *VSGetFrameFormat)(const VSFrameRef *f);
typedef int (__stdcall *VSGetFrameWidth)(const VSFrameRef *f, int plane);
typedef int (__stdcall *VSGetFrameHeight)(const VSFrameRef *f, int plane);
typedef const VSMap *(__stdcall *VSGetFramePropsRO)(const VSFrameRef *f);
typedef VSMap *(__stdcall *VSGetFramePropsRW)(VSFrameRef *f);
typedef int (__stdcall *VSPropNumKeys)(const VSMap *map);
typedef const char *(__stdcall *VSPropGetKey)(const VSMap *map, int index);
typedef int (__stdcall *VSPropNumElements)(const VSMap *map, const char *key);
typedef char(__stdcall *VSPropGetType)(const VSMap *map, const char *key);

typedef VSMap *(__stdcall *VSNewMap)(void);
typedef void (__stdcall *VSFreeMap)(VSMap *map);
typedef void (__stdcall *VSClearMap)(VSMap *map);

typedef int64_t (__stdcall *VSPropGetInt)(const VSMap *map, const char *key, int index, int *error);
typedef double(__stdcall *VSPropGetFloat)(const VSMap *map, const char *key, int index, int *error);
typedef const char *(__stdcall *VSPropGetData)(const VSMap *map, const char *key, int index, int *error);
typedef int (__stdcall *VSPropGetDataSize)(const VSMap *map, const char *key, int index, int *error);
typedef VSNodeRef *(__stdcall *VSPropGetNode)(const VSMap *map, const char *key, int index, int *error);
typedef const VSFrameRef *(__stdcall *VSPropGetFrame)(const VSMap *map, const char *key, int index, int *error);
typedef VSFuncRef *(__stdcall *VSPropGetFunc)(const VSMap *map, const char *key, int index, int *error);

typedef int (__stdcall *VSPropDeleteKey)(VSMap *map, const char *key);
typedef int (__stdcall *VSPropSetInt)(VSMap *map, const char *key, int64_t i, int append);
typedef int (__stdcall *VSPropSetFloat)(VSMap *map, const char *key, double d, int append);
typedef int (__stdcall *VSPropSetData)(VSMap *map, const char *key, const char *data, int size, int append);
typedef int (__stdcall *VSPropSetNode)(VSMap *map, const char *key, VSNodeRef *node, int append);
typedef int (__stdcall *VSPropSetFrame)(VSMap *map, const char *key, const VSFrameRef *f, int append);
typedef int (__stdcall *VSPropSetFunc)(VSMap *map, const char *key, VSFuncRef *func, int append);



typedef void (__stdcall *VSConfigPlugin)(const char *identifier, const char *defaultNamespace, const char *name, int apiVersion, int readonly, VSPlugin *plugin);
typedef void (__stdcall *VSInitPlugin)(VSConfigPlugin configFunc, VSRegisterFunction registerFunc, VSPlugin *plugin);

typedef VSPlugin *(__stdcall *VSGetPluginId)(const char *identifier, VSCore *core);
typedef VSPlugin *(__stdcall *VSGetPluginNs)(const char *ns, VSCore *core);

typedef VSMap *(__stdcall *VSGetPlugins)(VSCore *core);
typedef VSMap *(__stdcall *VSGetFunctions)(VSPlugin *plugin);

typedef void (__stdcall *VSCallFunc)(VSFuncRef *func, const VSMap *in, VSMap *out, VSCore *core, const VSAPI *vsapi);
typedef VSFuncRef *(__stdcall *VSCreateFunc)(VSPublicFunction func, void *userData, VSFreeFuncData free);

typedef void (__stdcall *VSQueryCompletedFrame)(VSNodeRef **node, int *n, VSFrameContext *frameCtx);
typedef void (__stdcall *VSReleaseFrameEarly)(VSNodeRef *node, int n, VSFrameContext *frameCtx);

typedef int64_t (__stdcall *VSSetMaxCacheSize)(int64_t bytes, VSCore *core);


struct VSAPI {
    VSCreateCore createCore;
    VSFreeCore freeCore;
    VSGetCoreInfo getCoreInfo;

    VSCloneFrameRef cloneFrameRef;
    VSCloneNodeRef cloneNodeRef;
    VSCloneFuncRef cloneFuncRef;

    VSFreeFrame freeFrame;
    VSFreeNode freeNode;
    VSFreeFunc freeFunc;

    VSNewVideoFrame newVideoFrame;
    VSCopyFrame copyFrame;
    VSCopyFrameProps copyFrameProps;

    VSRegisterFunction registerFunction;
    VSGetPluginId getPluginId;
    VSGetPluginNs getPluginNs;
    VSGetPlugins getPlugins;
    VSGetFunctions getFunctions;
    VSCreateFilter createFilter;
    VSSetError setError;
    VSGetError getError;
    VSSetFilterError setFilterError;
    VSInvoke invoke;

    VSGetFormatPreset getFormatPreset;
    VSRegisterFormat registerFormat;

    VSGetFrame getFrame;
    VSGetFrameAsync getFrameAsync;
    VSGetFrameFilter getFrameFilter;
    VSRequestFrameFilter requestFrameFilter;
    VSQueryCompletedFrame queryCompletedFrame;
    VSReleaseFrameEarly releaseFrameEarly;

    VSGetStride getStride;
    VSGetReadPtr getReadPtr;
    VSGetWritePtr getWritePtr;

    VSCreateFunc createFunc;
    VSCallFunc callFunc;


    VSNewMap newMap;
    VSFreeMap freeMap;
    VSClearMap clearMap;

    VSGetVideoInfo getVideoInfo;
    VSSetVideoInfo setVideoInfo;
    VSGetFrameFormat getFrameFormat;
    VSGetFrameWidth getFrameWidth;
    VSGetFrameHeight getFrameHeight;
    VSGetFramePropsRO getFramePropsRO;
    VSGetFramePropsRW getFramePropsRW;

    VSPropNumKeys propNumKeys;
    VSPropGetKey propGetKey;
    VSPropNumElements propNumElements;
    VSPropGetType propGetType;
    VSPropGetInt propGetInt;
    VSPropGetFloat propGetFloat;
    VSPropGetData propGetData;
    VSPropGetDataSize propGetDataSize;
    VSPropGetNode propGetNode;
    VSPropGetFrame propGetFrame;
    VSPropGetFunc propGetFunc;

    VSPropDeleteKey propDeleteKey;
    VSPropSetInt propSetInt;
    VSPropSetFloat propSetFloat;
    VSPropSetData propSetData;
    VSPropSetNode propSetNode;
    VSPropSetFrame propSetFrame;
    VSPropSetFunc propSetFunc;

    VSSetMaxCacheSize setMaxCacheSize;
    VSGetOutputIndex getOutputIndex;
    VSNewVideoFrame2 newVideoFrame2;
};

 __declspec(dllimport) const VSAPI * __stdcall getVapourSynthAPI(int version);

  ]]
end

return [[
typedef struct VSFrameRef VSFrameRef;
typedef struct VSNodeRef VSNodeRef;
typedef struct VSCore VSCore;
typedef struct VSPlugin VSPlugin;
typedef struct VSNode VSNode;
typedef struct VSFuncRef VSFuncRef;
typedef struct VSMap VSMap;
typedef struct VSAPI VSAPI;
typedef struct VSFrameContext VSFrameContext;

typedef enum VSColorFamily {
    cmGray = 1000000,
    cmRGB = 2000000,
    cmYUV = 3000000,
    cmYCoCg = 4000000,

    cmCompat = 9000000
} VSColorFamily;

typedef enum VSSampleType {
    stInteger = 0,
    stFloat = 1
} VSSampleType;


typedef enum VSPresetFormat {
    pfNone = 0,

    pfGray8 = cmGray + 10,
    pfGray16,

    pfGrayH,
    pfGrayS,

    pfYUV420P8 = cmYUV + 10,
    pfYUV422P8,
    pfYUV444P8,
    pfYUV410P8,
    pfYUV411P8,
    pfYUV440P8,

    pfYUV420P9,
    pfYUV422P9,
    pfYUV444P9,

    pfYUV420P10,
    pfYUV422P10,
    pfYUV444P10,

    pfYUV420P16,
    pfYUV422P16,
    pfYUV444P16,

    pfYUV444PH,
    pfYUV444PS,

    pfRGB24 = cmRGB + 10,
    pfRGB27,
    pfRGB30,
    pfRGB48,

    pfRGBH,
    pfRGBS,

    pfCompatBGR32 = cmCompat + 10,
    pfCompatYUY2
} VSPresetFormat;

typedef enum VSFilterMode {
    fmParallel = 100,
    fmParallelRequests = 200,
    fmUnordered = 300,
    fmSerial = 400
} VSFilterMode;

typedef struct VSFormat {
    char name[32];
    int id;
    int colorFamily;
    int sampleType;
    int bitsPerSample;
    int bytesPerSample;

    int subSamplingW;
    int subSamplingH;

    int numPlanes;
} VSFormat;

typedef enum NodeFlags {
    nfNoCache = 1,
} NodeFlags;

typedef enum GetPropErrors {
    peUnset = 1,
    peType = 2,
    peIndex = 4
} GetPropErrors;

typedef enum PropAppendMode {
    paReplace = 0,
    paAppend = 1,
    paTouch = 2
} PropAppendMode;

typedef struct VSCoreInfo {
    const char *versionString;
    int core;
    int api;
    int numThreads;
    int64_t maxFramebufferSize;
    int64_t usedFramebufferSize;
} VSCoreInfo;

typedef struct VSVideoInfo {
    const VSFormat *format;
    int64_t fpsNum;
    int64_t fpsDen;
    int width;
    int height;
    int numFrames;
    int flags;
} VSVideoInfo;

typedef enum ActivationReason {
    arInitial = 0,
    arFrameReady = 1,
    arAllFramesReady = 2,
    arError = -1
} ActivationReason;

typedef VSCore *( *VSCreateCore)(int threads);
typedef void ( *VSFreeCore)(VSCore *core);
typedef const VSCoreInfo *( *VSGetCoreInfo)(VSCore *core);

typedef void ( *VSPublicFunction)(const VSMap *in, VSMap *out, void *userData, VSCore *core, const VSAPI *vsapi);
typedef void ( *VSFreeFuncData)(void *userData);
typedef void ( *VSFilterInit)(VSMap *in, VSMap *out, void **instanceData, VSNode *node, VSCore *core, const VSAPI *vsapi);
typedef const VSFrameRef *( *VSFilterGetFrame)(int n, int activationReason, void **instanceData, void **frameData, VSFrameContext *frameCtx, VSCore *core, const VSAPI *vsapi);
typedef int ( *VSGetOutputIndex)(VSFrameContext *frameCtx);
typedef void ( *VSFilterFree)(void *instanceData, VSCore *core, const VSAPI *vsapi);
typedef void ( *VSRegisterFunction)(const char *name, const char *args, VSPublicFunction argsFunc, void *functionData, VSPlugin *plugin);
typedef void ( *VSCreateFilter)(const VSMap *in, VSMap *out, const char *name, VSFilterInit init, VSFilterGetFrame getFrame, VSFilterFree free, int filterMode, int flags, void *instanceData, VSCore *core);
typedef VSMap *( *VSInvoke)(VSPlugin *plugin, const char *name, const VSMap *args);
typedef void ( *VSSetError)(VSMap *map, const char *errorMessage);
typedef const char *( *VSGetError)(const VSMap *map);
typedef void ( *VSSetFilterError)(const char *errorMessage, VSFrameContext *frameCtx);

typedef const VSFormat *( *VSGetFormatPreset)(int id, VSCore *core);
typedef const VSFormat *( *VSRegisterFormat)(int colorFamily, int sampleType, int bitsPerSample, int subSamplingW, int subSamplingH, VSCore *core);


typedef void ( *VSFrameDoneCallback)(void *userData, const VSFrameRef *f, int n, VSNodeRef *, const char *errorMsg);
typedef void ( *VSGetFrameAsync)(int n, VSNodeRef *node, VSFrameDoneCallback callback, void *userData);
typedef const VSFrameRef *( *VSGetFrame)(int n, VSNodeRef *node, char *errorMsg, int bufSize);
typedef void ( *VSRequestFrameFilter)(int n, VSNodeRef *node, VSFrameContext *frameCtx);
typedef const VSFrameRef *( *VSGetFrameFilter)(int n, VSNodeRef *node, VSFrameContext *frameCtx);
typedef const VSFrameRef *( *VSCloneFrameRef)(const VSFrameRef *f);
typedef VSNodeRef *( *VSCloneNodeRef)(VSNodeRef *node);
typedef VSFuncRef *( *VSCloneFuncRef)(VSFuncRef *f);
typedef void ( *VSFreeFrame)(const VSFrameRef *f);
typedef void ( *VSFreeNode)(VSNodeRef *node);
typedef void ( *VSFreeFunc)(VSFuncRef *f);
typedef VSFrameRef *( *VSNewVideoFrame)(const VSFormat *format, int width, int height, const VSFrameRef *propSrc, VSCore *core);
typedef VSFrameRef *( *VSNewVideoFrame2)(const VSFormat *format, int width, int height, const VSFrameRef **planeSrc, const int *planes, const VSFrameRef *propSrc, VSCore *core);
typedef VSFrameRef *( *VSCopyFrame)(const VSFrameRef *f, VSCore *core);
typedef void ( *VSCopyFrameProps)(const VSFrameRef *src, VSFrameRef *dst, VSCore *core);
typedef int ( *VSGetStride)(const VSFrameRef *f, int plane);
typedef const uint8_t *( *VSGetReadPtr)(const VSFrameRef *f, int plane);
typedef uint8_t *( *VSGetWritePtr)(VSFrameRef *f, int plane);


typedef const VSVideoInfo *( *VSGetVideoInfo)(VSNodeRef *node);
typedef void ( *VSSetVideoInfo)(const VSVideoInfo *vi, int numOutputs, VSNode *node);
typedef const VSFormat *( *VSGetFrameFormat)(const VSFrameRef *f);
typedef int ( *VSGetFrameWidth)(const VSFrameRef *f, int plane);
typedef int ( *VSGetFrameHeight)(const VSFrameRef *f, int plane);
typedef const VSMap *( *VSGetFramePropsRO)(const VSFrameRef *f);
typedef VSMap *( *VSGetFramePropsRW)(VSFrameRef *f);
typedef int ( *VSPropNumKeys)(const VSMap *map);
typedef const char *( *VSPropGetKey)(const VSMap *map, int index);
typedef int ( *VSPropNumElements)(const VSMap *map, const char *key);
typedef char( *VSPropGetType)(const VSMap *map, const char *key);

typedef VSMap *( *VSNewMap)(void);
typedef void ( *VSFreeMap)(VSMap *map);
typedef void ( *VSClearMap)(VSMap *map);

typedef int64_t ( *VSPropGetInt)(const VSMap *map, const char *key, int index, int *error);
typedef double( *VSPropGetFloat)(const VSMap *map, const char *key, int index, int *error);
typedef const char *( *VSPropGetData)(const VSMap *map, const char *key, int index, int *error);
typedef int ( *VSPropGetDataSize)(const VSMap *map, const char *key, int index, int *error);
typedef VSNodeRef *( *VSPropGetNode)(const VSMap *map, const char *key, int index, int *error);
typedef const VSFrameRef *( *VSPropGetFrame)(const VSMap *map, const char *key, int index, int *error);
typedef VSFuncRef *( *VSPropGetFunc)(const VSMap *map, const char *key, int index, int *error);

typedef int ( *VSPropDeleteKey)(VSMap *map, const char *key);
typedef int ( *VSPropSetInt)(VSMap *map, const char *key, int64_t i, int append);
typedef int ( *VSPropSetFloat)(VSMap *map, const char *key, double d, int append);
typedef int ( *VSPropSetData)(VSMap *map, const char *key, const char *data, int size, int append);
typedef int ( *VSPropSetNode)(VSMap *map, const char *key, VSNodeRef *node, int append);
typedef int ( *VSPropSetFrame)(VSMap *map, const char *key, const VSFrameRef *f, int append);
typedef int ( *VSPropSetFunc)(VSMap *map, const char *key, VSFuncRef *func, int append);



typedef void ( *VSConfigPlugin)(const char *identifier, const char *defaultNamespace, const char *name, int apiVersion, int readonly, VSPlugin *plugin);
typedef void ( *VSInitPlugin)(VSConfigPlugin configFunc, VSRegisterFunction registerFunc, VSPlugin *plugin);

typedef VSPlugin *( *VSGetPluginId)(const char *identifier, VSCore *core);
typedef VSPlugin *( *VSGetPluginNs)(const char *ns, VSCore *core);

typedef VSMap *( *VSGetPlugins)(VSCore *core);
typedef VSMap *( *VSGetFunctions)(VSPlugin *plugin);

typedef void ( *VSCallFunc)(VSFuncRef *func, const VSMap *in, VSMap *out, VSCore *core, const VSAPI *vsapi);
typedef VSFuncRef *( *VSCreateFunc)(VSPublicFunction func, void *userData, VSFreeFuncData free);

typedef void ( *VSQueryCompletedFrame)(VSNodeRef **node, int *n, VSFrameContext *frameCtx);
typedef void ( *VSReleaseFrameEarly)(VSNodeRef *node, int n, VSFrameContext *frameCtx);

typedef int64_t ( *VSSetMaxCacheSize)(int64_t bytes, VSCore *core);


struct VSAPI {
    VSCreateCore createCore;
    VSFreeCore freeCore;
    VSGetCoreInfo getCoreInfo;

    VSCloneFrameRef cloneFrameRef;
    VSCloneNodeRef cloneNodeRef;
    VSCloneFuncRef cloneFuncRef;

    VSFreeFrame freeFrame;
    VSFreeNode freeNode;
    VSFreeFunc freeFunc;

    VSNewVideoFrame newVideoFrame;
    VSCopyFrame copyFrame;
    VSCopyFrameProps copyFrameProps;

    VSRegisterFunction registerFunction;
    VSGetPluginId getPluginId;
    VSGetPluginNs getPluginNs;
    VSGetPlugins getPlugins;
    VSGetFunctions getFunctions;
    VSCreateFilter createFilter;
    VSSetError setError;
    VSGetError getError;
    VSSetFilterError setFilterError;
    VSInvoke invoke;

    VSGetFormatPreset getFormatPreset;
    VSRegisterFormat registerFormat;

    VSGetFrame getFrame;
    VSGetFrameAsync getFrameAsync;
    VSGetFrameFilter getFrameFilter;
    VSRequestFrameFilter requestFrameFilter;
    VSQueryCompletedFrame queryCompletedFrame;
    VSReleaseFrameEarly releaseFrameEarly;

    VSGetStride getStride;
    VSGetReadPtr getReadPtr;
    VSGetWritePtr getWritePtr;

    VSCreateFunc createFunc;
    VSCallFunc callFunc;


    VSNewMap newMap;
    VSFreeMap freeMap;
    VSClearMap clearMap;

    VSGetVideoInfo getVideoInfo;
    VSSetVideoInfo setVideoInfo;
    VSGetFrameFormat getFrameFormat;
    VSGetFrameWidth getFrameWidth;
    VSGetFrameHeight getFrameHeight;
    VSGetFramePropsRO getFramePropsRO;
    VSGetFramePropsRW getFramePropsRW;

    VSPropNumKeys propNumKeys;
    VSPropGetKey propGetKey;
    VSPropNumElements propNumElements;
    VSPropGetType propGetType;
    VSPropGetInt propGetInt;
    VSPropGetFloat propGetFloat;
    VSPropGetData propGetData;
    VSPropGetDataSize propGetDataSize;
    VSPropGetNode propGetNode;
    VSPropGetFrame propGetFrame;
    VSPropGetFunc propGetFunc;

    VSPropDeleteKey propDeleteKey;
    VSPropSetInt propSetInt;
    VSPropSetFloat propSetFloat;
    VSPropSetData propSetData;
    VSPropSetNode propSetNode;
    VSPropSetFrame propSetFrame;
    VSPropSetFunc propSetFunc;

    VSSetMaxCacheSize setMaxCacheSize;
    VSGetOutputIndex getOutputIndex;
    VSNewVideoFrame2 newVideoFrame2;
};

__attribute__((visibility("default"))) const VSAPI * getVapourSynthAPI(int version);
]]
