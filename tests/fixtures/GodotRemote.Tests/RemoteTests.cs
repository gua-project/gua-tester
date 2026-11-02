using Gua.Testing.Godot;
using NUnit.Framework;

public sealed class RemoteTests
{
    [Test]
    public void PublishedSdkCanOperateTheLiveGodotUi()
    {
        var project = Path.GetFullPath(Path.Combine(TestContext.CurrentContext.TestDirectory, "../../../../godot"));
        var userData = Directory.CreateDirectory(Path.Combine(project, ".userdata")).FullName;
        using var host = GodotSceneTestHost.Load("res://main.tscn", new GodotSceneTestHostOptions
        {
            ProjectPath = project,
            UseAvailableBridgePort = true,
            Headless = true,
            EnvironmentVariables = new Dictionary<string, string>
            {
                ["APPDATA"] = userData,
                ["LOCALAPPDATA"] = userData,
            },
        });
        Assert.That(() => host.RemoteContext.FindNodeByText("Start"), Is.Not.Empty.After(5000, 50));
        var id = host.RemoteContext.FindNodeByText("Start");
        Assert.That(host.RemoteContext.EnqueueClick(id), Is.True);
        Assert.That(() => host.RemoteContext.FindNodeByText("Clicked"), Is.Not.Empty.After(5000, 50));
    }
}
