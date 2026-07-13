int main(string[] args) {
    var expected_provider = (args[1] == "lua")
        ? AstalHyprland.ConfigProvider.LUA
        : AstalHyprland.ConfigProvider.HYPRLANG;
    var hyprland = AstalHyprland.get_default();

    assert(hyprland.config_provider == expected_provider);
    assert(hyprland.clients.length() == 2);
    assert(hyprland.groups.length() == 1);

    var client = hyprland.get_client("aaa");
    var workspace = hyprland.get_workspace(1);
    var monitor = hyprland.get_monitor(1);
    var group = client.group;
    assert(group != null);
    assert(group.clients.length() == 2);
    assert(group.visible_client == client);
    assert(workspace.groups.length() == 1);

    client.kill();
    client.focus();
    client.move_to(workspace);
    client.toggle_floating();
    workspace.focus();
    workspace.move_to(monitor);
    monitor.focus();
    hyprland.move_cursor(10, 20);

    var loop = new MainLoop();
    var membership_changed = false;
    hyprland.client_removed_from_group.connect((removed, previous_group) => {
        if (removed == client) {
            membership_changed = true;
            assert(previous_group == group);
        }
    });
    hyprland.event.connect((event, payload) => {
        if (event == "moveoutofgroup") loop.quit();
    });

    assert(hyprland.message("test/update") == "ok");
    Timeout.add(3000, () => {
        loop.quit();
        return Source.REMOVE;
    });
    loop.run();

    assert(membership_changed);
    assert(client.group == null);
    assert(hyprland.get_client("bbb").group == group);
    assert(group.clients.length() == 1);
    assert(hyprland.groups.length() == 1);
    return 0;
}