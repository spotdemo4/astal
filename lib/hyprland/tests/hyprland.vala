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
    var awaited_event = "moveoutofgroup";
    var membership_changed = false;
    hyprland.client_removed_from_group.connect((removed, previous_group) => {
        if (removed == client) {
            membership_changed = true;
            assert(previous_group == group);
        }
    });
    hyprland.event.connect((event, payload) => {
        if (event == awaited_event) loop.quit();
    });

    assert(hyprland.message("test/update") == "ok");
    Timeout.add(10000, () => {
        loop.quit();
        return Source.REMOVE;
    });
    loop.run();

    assert(membership_changed);
    assert(client.group == null);
    assert(hyprland.get_client("bbb").group == group);
    assert(group.clients.length() == 1);
    assert(hyprland.groups.length() == 1);

    AstalHyprland.Client? opened_client = null;
    var client_added = false;
    var membership_added = false;
    hyprland.client_added.connect((added) => {
        if (added.address == "ccc") {
            assert(!membership_added);
            assert(added.group == null);
            opened_client = added;
            client_added = true;
        }
    });
    hyprland.client_added_to_group.connect((added, added_group) => {
        if (added.address == "ccc") {
            assert(client_added);
            assert(added.group == group);
            assert(added_group == group);
            membership_added = true;
        }
    });

    awaited_event = "openwindow";
    assert(hyprland.message("test/open") == "ok");
    loop.run();

    assert(client_added);
    assert(membership_added);
    assert(opened_client != null);
    assert(opened_client.group == group);
    assert(group.clients.length() == 2);

    var membership_removed = false;
    var client_removed = false;
    var removed_emitted = false;
    opened_client.removed.connect(() => removed_emitted = true);
    hyprland.client_removed_from_group.connect((removed, previous_group) => {
        if (removed == opened_client) {
            assert(removed.group == null);
            assert(previous_group == group);
            foreach (var member in group.clients) assert(member != removed);
            membership_removed = true;
        }
    });
    hyprland.client_removed.connect((address) => {
        if (address == "ccc") client_removed = true;
    });

    awaited_event = "closewindow";
    assert(hyprland.message("test/close") == "ok");
    loop.run();

    assert(membership_removed);
    assert(client_removed);
    assert(removed_emitted);
    assert(opened_client.group == null);
    assert(group.clients.length() == 1);
    assert(hyprland.get_client("ccc") == null);
    return 0;
}
