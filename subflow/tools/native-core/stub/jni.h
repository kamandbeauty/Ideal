// Minimal jni.h stub used ONLY for `g++ -fsyntax-only` checks of sf_jni.cpp in
// the host sandbox (the real header comes from the Android NDK). It declares
// exactly the JNI surface the bridge uses; it is never linked or shipped.
#pragma once

#include <cstddef>

typedef int jint;
typedef long long jlong;
typedef double jdouble;
typedef float jfloat;
typedef bool jboolean;
typedef jint jsize;
typedef int jshort;
typedef signed char jbyte;

#define JNI_TRUE true
#define JNI_FALSE false
#define JNI_VERSION_1_6 0x00010006
#define JNIEXPORT
#define JNICALL

struct _jobject;
typedef _jobject* jobject;
typedef _jobject* jclass;
typedef _jobject* jstring;
typedef _jobject* jarray;
typedef _jobject* jobjectArray;
typedef _jobject* jlongArray;
typedef _jobject* jfloatArray;

struct JavaVM;

struct JNIEnv {
  jclass FindClass(const char*);
  jint ThrowNew(jclass, const char*);
  const char* GetStringUTFChars(jstring, jboolean*);
  void ReleaseStringUTFChars(jstring, const char*);
  jsize GetArrayLength(jarray);
  void GetLongArrayRegion(jlongArray, jsize, jsize, jlong*);
  void GetFloatArrayRegion(jfloatArray, jsize, jsize, jfloat*);
  void SetLongArrayRegion(jlongArray, jsize, jsize, const jlong*);
  jlongArray NewLongArray(jsize);
  jobject GetObjectArrayElement(jobjectArray, jsize);
  void DeleteLocalRef(jobject);
  jboolean ExceptionCheck();
  jstring NewStringUTF(const char*);
};
