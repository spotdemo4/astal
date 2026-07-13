namespace AstalHyprland {
public class Workspace : Object {
    public signal void removed();

    public List<weak Client> _clients = new List<weak Client>();
    private List<weak Group> _groups = new List<weak Group>();

    public int id { get; private set; }
    public string name { get; private set; }
    public Monitor monitor { get; private set; }
    public List<weak Client> clients { owned get { return _clients.copy(); } }
    public List<weak Group> groups { owned get { return _groups.copy(); } }
    public bool has_fullscreen { get; private set; }
    public Client last_client { get; private set; }

    public Workspace.dummy(int id, Monitor ? monitor) {
        this.id = id;
        this.name = id.to_string();
        this.monitor = monitor;
    }

    internal List<weak Client> filter_clients() {
        var hyprland = Hyprland.get_default();
        var list = new List<weak Client>();
        foreach (var client in hyprland.clients) {
            if (client.workspace == this) {
                list.append(client);
            }
        }

        return list;
    }

    private bool same_clients(List<weak Client> clients) {
        if (_clients.length() != clients.length()) return false;
        foreach (var client in clients) {
            if (_clients.find(client) == null) return false;
        }
        return true;
    }

    private bool same_groups(List<weak Group> groups) {
        if (_groups.length() != groups.length()) return false;
        foreach (var group in groups) {
            if (_groups.find(group) == null) return false;
        }
        return true;
    }

    internal void sync_groups() {
        var groups = new List<weak Group>();
        foreach (var group in Hyprland.get_default().groups) {
            if (group.workspace == this) groups.append(group);
        }

        if (!same_groups(groups)) {
            _groups = groups.copy();
            notify_property("groups");
        }
    }

    internal void sync(Json.Object obj) {
        var hyprland = Hyprland.get_default();

        id = (int)obj.get_int_member("id");
        name = obj.get_string_member("name");
        has_fullscreen = obj.get_boolean_member("hasfullscreen");

        monitor = hyprland.get_monitor((int)obj.get_int_member("monitorID"));
        last_client = hyprland.get_client(obj.get_string_member("lastwindow"));

        var list = filter_clients();
        if (!same_clients(list)) {
            _clients = list.copy();
            notify_property("clients");
        }
        sync_groups();
    }

    public void focus() {
        Hyprland.get_default().dispatch_action(
            "workspace",
            id.to_string(),
            "hl.dsp.focus({ workspace = %d })".printf(id)
        );
    }

    public void move_to(Monitor m) {
        Hyprland.get_default().dispatch_action(
            "moveworkspacetomonitor",
            id.to_string() + " " + m.id.to_string(),
            "hl.dsp.workspace.move({ workspace = %d, monitor = %d })".printf(id, m.id)
        );
    }
}
}
