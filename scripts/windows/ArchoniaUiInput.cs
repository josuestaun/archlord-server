using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading;

public static class ArchoniaUiInput
{
    [StructLayout(LayoutKind.Sequential)]
    private struct Rect { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point { public int X, Y; }

    [DllImport("user32.dll")] private static extern bool GetClientRect(IntPtr hwnd, out Rect rect);
    [DllImport("user32.dll")] private static extern bool ClientToScreen(IntPtr hwnd, ref Point point);
    [DllImport("user32.dll", SetLastError = true)] private static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr hwnd, int command);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint thread, uint other, bool attach);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] private static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] private static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern short VkKeyScan(char value);
    [DllImport("user32.dll")] private static extern uint MapVirtualKey(uint key, uint mapping);

    private static void Guard(IntPtr target)
    {
        if (GetForegroundWindow() != target)
            throw new InvalidOperationException("The test copy lost foreground focus.");
    }

    private static void Focus(IntPtr target)
    {
        if (GetForegroundWindow() == target) return;

        ShowWindowAsync(target, 9);
        SetForegroundWindow(target);
        Thread.Sleep(120);
        if (GetForegroundWindow() == target) return;

        uint pid;
        uint active = GetWindowThreadProcessId(GetForegroundWindow(), out pid);
        uint current = GetCurrentThreadId();
        bool attached = active != 0 && active != current && AttachThreadInput(current, active, true);
        try
        {
            BringWindowToTop(target);
            SetForegroundWindow(target);
        }
        finally
        {
            if (attached) AttachThreadInput(current, active, false);
        }
        Thread.Sleep(150);
        Guard(target);
    }

    public static void Click(IntPtr target, int x, int y, bool rightButton)
    {
        Rect rect;
        if (!GetClientRect(target, out rect) || rect.Right != 1920 || rect.Bottom != 1080)
            throw new InvalidOperationException("The graphical test needs a 1920x1080 client area.");
        if (x < 0 || y < 0 || x >= rect.Right || y >= rect.Bottom)
            throw new ArgumentOutOfRangeException("x", "The click is outside the test window.");

        Focus(target);
        var point = new Point { X = x, Y = y };
        if (!ClientToScreen(target, ref point) || !SetCursorPos(point.X, point.Y)) throw new Win32Exception();
        Thread.Sleep(160);
        Guard(target);
        mouse_event(rightButton ? 8u : 2u, 0, 0, 0, UIntPtr.Zero);
        Thread.Sleep(100);
        mouse_event(rightButton ? 16u : 4u, 0, 0, 0, UIntPtr.Zero);
    }

    private static void Key(IntPtr target, byte key)
    {
        Guard(target);
        byte scan = (byte)MapVirtualKey(key, 0);
        keybd_event(key, scan, 0, UIntPtr.Zero);
        Thread.Sleep(35);
        keybd_event(key, scan, 2, UIntPtr.Zero);
    }

    public static void Press(IntPtr target, byte key)
    {
        Focus(target);
        Key(target, key);
    }

    private static void FillField(IntPtr target, string value)
    {
        Guard(target);
        keybd_event(17, 0, 0, UIntPtr.Zero);
        try { Key(target, 65); }
        finally { keybd_event(17, 0, 2, UIntPtr.Zero); }
        for (int i = 0; i < 25; i++) Key(target, 8);

        foreach (char character in value)
        {
            short mapping = VkKeyScan(character);
            if (mapping < 0 || (mapping >> 8) > 1) throw new InvalidOperationException("Unsupported test credential character.");
            bool shift = (mapping >> 8) == 1;
            Guard(target);
            if (shift) keybd_event(16, 0, 0, UIntPtr.Zero);
            try { Key(target, (byte)mapping); }
            finally { if (shift) keybd_event(16, 0, 2, UIntPtr.Zero); }
            Thread.Sleep(45);
        }
    }

    public static void FillLogin(IntPtr target, string user, string password)
    {
        Click(target, 1000, 547, false);
        FillField(target, user);
        Click(target, 1000, 570, false);
        FillField(target, password);
        Click(target, 904, 611, false);
    }
}
