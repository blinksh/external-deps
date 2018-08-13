#!/bin/bash
set -e

LIBMOSH_VER="1.3.2-8cd6688"
PROTOBF_VER="2.6.1"
IOS_SYSTEM_VER="2.1"

GHROOT="https://github.com/blinksh"
HHROOT="https://github.com/holzschu"

rm -rf ./Frameworks
mkdir ./Frameworks
mkdir ./Frameworks/lib


(

cd Frameworks
echo "Downloading libmoshios-$LIBMOSH_VER.framework.tar.gz"
curl -OL $GHROOT/build-mosh/releases/download/$LIBMOSH_VER/libmoshios-$LIBMOSH_VER.framework.tar.gz
( tar -zxf libmoshios-*.tar.gz && rm libmoshios-*.tar.gz ) || { echo "Libmoshios framework failed to download"; exit 1; }
# protobuf
echo "Downloading protobuf-$PROTOBF_VER.framework.tar.gz"
curl -OL $GHROOT/build-protobuf/releases/download/$PROTOBF_VER/protobuf-$PROTOBF_VER.tar.gz
( tar -zxf protobuf-*.tar.gz && cp protobuf-*/lib/libprotobuf.a ./lib/ && rm -rf protobuf-* ) || { echo "Protobuf framework failed to download"; exit 1; }

)


git clone --depth 1 --recursive https://github.com/holzschu/libssh2-for-iOS.git libssh2

(
echo "Building openssl"
cd libssh2
./openssl/build-libssl.sh
# Make dynamic framework, with embed-bitcode, iOS + Simulator:
rm -rf build
rm -rf openssl.framework
xcodebuild -project libssh2-for-iOS.xcodeproj -target openssl -sdk iphoneos -arch arm64 -configuration Release
mkdir -p build/Release-iphoneos/openssl.framework/Headers/
cp include/openssl/* build/Release-iphoneos/openssl.framework/Headers/
#xcodebuild -project libssh2-for-iOS.xcodeproj -target openssl -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=10.0' -arch x86_64 -arch i386  -configuration Debug
#mkdir -p build/Debug-iphonesimulator/openssl.framework/Headers/
#cp include/openssl/* build/Debug-iphonesimulator/openssl.framework/Headers/
cp -r build/Release-iphoneos/openssl.framework .
#lipo -create -output openssl.framework/openssl build/Debug-iphonesimulator/openssl.framework/openssl build/Debug-iphoneos/openssl.framework/openssl
lipo -create -output openssl.framework/openssl build/Release-iphoneos/openssl.framework/openssl
# if you don't need bitcode, use this line instead:
# ./openssl/create-openssl-framework.sh dynamic
echo "Build libssh2:"
./build-libssh2.sh openssl
# Make dynamic framework, with embed-bitcode, iOS + Simulator:
rm -rf libssh2.framework
xcodebuild -project libssh2-for-iOS.xcodeproj -target libssh2 -sdk iphoneos -arch arm64 -configuration Release
mkdir -p build/Release-iphoneos/libssh2.framework/Headers/
cp include/libssh2/* build/Release-iphoneos/libssh2.framework/Headers/
#xcodebuild -project libssh2-for-iOS.xcodeproj -target libssh2 -sdk iphonesimulator -destination 'platform=iOS Simulator,OS=10.0' -arch x86_64 -arch i386  -configuration Debug
#mkdir -p build/Debug-iphonesimulator/libssh2.framework/Headers/
#cp include/libssh2/* build/Debug-iphonesimulator/libssh2.framework/Headers/
cp -r build/Release-iphoneos/libssh2.framework .
#lipo -create -output libssh2.framework/libssh2 build/Debug-iphonesimulator/libssh2.framework/libssh2 build/Debug-iphoneos/libssh2.framework/libssh2
lipo -create -output libssh2.framework/libssh2 build/Release-iphoneos/libssh2.framework/libssh2
# if you don't need bitcode, use this line instead:
# ./create-libssh2-framework.sh dynamic
)


cp -r ./libssh2/openssl.framework ./Frameworks/
cp -r ./libssh2/libssh2.framework ./Frameworks/

#rm -rf libssh2

git clone --depth 1 --recursive https://github.com/holzschu/ios_system.git ios_system

cp -r ./Frameworks/openssl.framework ./ios_system/Frameworks/
cp -r ./Frameworks/libssh2.framework ./ios_system/Frameworks/

(
echo "Building ios_system"
cd ./ios_system
./get_sources.sh
xcodebuild -project ios_system.xcodeproj -target ios_system -sdk iphoneos -arch arm64 -configuration Release | xcpretty
cp -rf ./build/Release-iphoneos/ios_system.framework ./Frameworks/

xcodebuild -project ios_system.xcodeproj -target awk -sdk iphoneos -arch arm64 -configuration Release | xcpretty
xcodebuild -project ios_system.xcodeproj -target curl_ios -sdk iphoneos -arch arm64 -configuration Release | xcpretty
xcodebuild -project ios_system.xcodeproj -target files -sdk iphoneos -arch arm64 -configuration Release | xcpretty
xcodebuild -project ios_system.xcodeproj -target shell -sdk iphoneos -arch arm64 -configuration Release | xcpretty
xcodebuild -project ios_system.xcodeproj -target ssh_cmd -sdk iphoneos -arch arm64 -configuration Release | xcpretty
xcodebuild -project ios_system.xcodeproj -target tar -sdk iphoneos -arch arm64 -configuration Release | xcpretty
xcodebuild -project ios_system.xcodeproj -target text -sdk iphoneos -arch arm64 -configuration Release | xcpretty

cp -rf ./build/Release-iphoneos/*.framework ../Frameworks
)

#rm -rf ./ios_system

echo "Cloning network_ios"

git clone --depth 1 --recursive https://github.com/holzschu/network_ios.git network_ios

cp -rf ./Frameworks/openssl.framework ./network_ios/Frameworks/
cp -rf ./Frameworks/libssh2.framework ./network_ios/Frameworks/
cp -rf ./Frameworks/ios_system.framework ./network_ios/Frameworks/

(
echo "Building network_ios"
cd ./network_ios
echo "Downloading header file:"
curl -OL $HHROOT/ios_system/releases/download/v$IOS_SYSTEM_VER/ios_error.h 
xcodebuild -project network_ios.xcodeproj -target network_ios -sdk iphoneos -arch arm64 -configuration Release | xcpretty
cp -rf ./build/Release-iphoneos/*.framework ../Frameworks/
)
rm -rf ./network_ios

(
echo "Building libssh"
git clone --depth 1 -b runloop --recursive https://github.com/yury/libssh.git
cd polly/bin
python3 build.py --clear --verbosity-level=silent --toolchain ios-nocodesign --fwd OPENSSL_ROOT_DIR=../../libssh2/openssl CMAKE_INSTALL_RPATH=@rpath/ WITH_STATIC_LIB=ON --ios-multiarch --framework --ios-combined --config Release --home ../../libssh
cp _install/ios-nocodesign/lib/libssh.a ../../Frameworks/lib/libsshd.a
cp -r _install/ios-nocodesign/include ../../Frameworks/include
)
