#define NOMINMAX
#include <windows.h>
#include <d3d11.h>
#include <wincodec.h>
#include <windows.graphics.capture.interop.h>
#include <windows.graphics.directx.direct3d11.interop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Graphics.Capture.h>
#include <winrt/Windows.Graphics.DirectX.Direct3D11.h>
#include <cwchar>
#include <iostream>

using namespace winrt;
using namespace winrt::Windows::Graphics::Capture;
using namespace winrt::Windows::Graphics::DirectX;
using namespace winrt::Windows::Graphics::DirectX::Direct3D11;

static void savePng(const wchar_t* path, UINT width, UINT height, UINT pitch, BYTE* pixels) {
    com_ptr<IWICImagingFactory> factory;
    check_hresult(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(factory.put())));
    com_ptr<IWICStream> stream;
    check_hresult(factory->CreateStream(stream.put()));
    check_hresult(stream->InitializeFromFilename(path, GENERIC_WRITE));
    com_ptr<IWICBitmapEncoder> encoder;
    check_hresult(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, encoder.put()));
    check_hresult(encoder->Initialize(stream.get(), WICBitmapEncoderNoCache));
    com_ptr<IWICBitmapFrameEncode> frame;
    check_hresult(encoder->CreateNewFrame(frame.put(), nullptr));
    check_hresult(frame->Initialize(nullptr));
    check_hresult(frame->SetSize(width, height));
    auto format = GUID_WICPixelFormat32bppBGRA;
    check_hresult(frame->SetPixelFormat(&format));
    if (format != GUID_WICPixelFormat32bppBGRA) throw hresult_error(E_FAIL, L"Unexpected PNG pixel format");
    check_hresult(frame->WritePixels(height, pitch, pitch * height, pixels));
    check_hresult(frame->Commit());
    check_hresult(encoder->Commit());
}

int wmain(int argc, wchar_t** argv) {
    if (argc != 4) return 2;
    auto window = reinterpret_cast<HWND>(std::wcstoull(argv[1], nullptr, 10));
    auto expectedPid = std::wcstoul(argv[2], nullptr, 10);
    DWORD pid = 0;
    GetWindowThreadProcessId(window, &pid);
    if (!IsWindow(window) || pid == 0 || pid != expectedPid) return 3;
    try {
        init_apartment();
        if (!GraphicsCaptureSession::IsSupported()) throw hresult_error(E_NOTIMPL, L"Windows Graphics Capture unavailable");
        auto factory = get_activation_factory<GraphicsCaptureItem, IGraphicsCaptureItemInterop>();
        GraphicsCaptureItem item{nullptr};
        check_hresult(factory->CreateForWindow(window, guid_of<GraphicsCaptureItem>(), put_abi(item)));
        const auto size = item.Size();
        if (size.Width < 320 || size.Height < 200 || size.Width > 3840 || size.Height > 2160) return 4;

        com_ptr<ID3D11Device> device;
        com_ptr<ID3D11DeviceContext> context;
        check_hresult(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
            nullptr, 0, D3D11_SDK_VERSION, device.put(), nullptr, context.put()));
        com_ptr<::IInspectable> dxgiDevice;
        check_hresult(CreateDirect3D11DeviceFromDXGIDevice(device.as<IDXGIDevice>().get(), dxgiDevice.put()));
        auto pool = Direct3D11CaptureFramePool::CreateFreeThreaded(dxgiDevice.as<IDirect3DDevice>(),
            DirectXPixelFormat::B8G8R8A8UIntNormalized, 1, size);
        auto capture = pool.CreateCaptureSession(item);
        capture.StartCapture();
        Direct3D11CaptureFrame frame{nullptr};
        for (int attempt = 0; attempt < 50 && !frame; ++attempt) {
            Sleep(50);
            frame = pool.TryGetNextFrame();
        }
        if (!frame) throw hresult_error(E_FAIL, L"No frame received");
        const auto info = frame.Surface().as<::Windows::Graphics::DirectX::Direct3D11::IDirect3DDxgiInterfaceAccess>();
        com_ptr<ID3D11Texture2D> texture;
        check_hresult(info->GetInterface(__uuidof(ID3D11Texture2D), texture.put_void()));
        D3D11_TEXTURE2D_DESC desc{};
        texture->GetDesc(&desc);
        desc.BindFlags = 0;
        desc.MiscFlags = 0;
        desc.Usage = D3D11_USAGE_STAGING;
        desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
        com_ptr<ID3D11Texture2D> staging;
        check_hresult(device->CreateTexture2D(&desc, nullptr, staging.put()));
        context->CopyResource(staging.get(), texture.get());
        D3D11_MAPPED_SUBRESOURCE map{};
        check_hresult(context->Map(staging.get(), 0, D3D11_MAP_READ, 0, &map));
        try { savePng(argv[3], desc.Width, desc.Height, map.RowPitch, static_cast<BYTE*>(map.pData)); }
        catch (...) { context->Unmap(staging.get(), 0); throw; }
        context->Unmap(staging.get(), 0);
        frame.Close();
        capture.Close();
        pool.Close();
        return 0;
    } catch (const hresult_error& error) {
        std::wcerr << L"Capture HRESULT 0x" << std::hex << static_cast<unsigned>(error.code()) << L": " << error.message().c_str() << std::endl;
        return 5;
    }
}
