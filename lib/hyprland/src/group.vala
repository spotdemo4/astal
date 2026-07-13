namespace AstalHyprland {
/** A Hyprland group reconstructed from the grouped fields in j/clients. */
public class Group : Object {
    public signal void destroyed();
    public signal void moved_to(Workspace workspace);

    private List<weak Client> _clients = new List<weak Client>();
    public List<weak Client> clients { owned get { return _clients.copy(); } }

    /** The visible member, or null when this group's workspace is not visible. */
    public weak Client? visible_client { get; private set; }
    public weak Workspace? workspace { get; private set; }
    public weak Monitor? monitor { get; private set; }
    public bool mapped { get; private set; }
    public bool hidden { get; private set; }
    public int x { get; private set; }
    public int y { get; private set; }
    public int width { get; private set; }
    public int height { get; private set; }
    public bool floating { get; private set; }
    public bool pinned { get; private set; }

    private bool same_clients(List<weak Client> clients) {
        if (_clients.length() != clients.length()) return false;

        for (uint i = 0; i < _clients.length(); i++) {
            if (_clients.nth_data(i) != clients.nth_data(i)) return false;
        }

        return true;
    }

    internal int overlap(List<string> addresses) {
        var count = 0;
        foreach (var client in _clients) {
            foreach (var address in addresses) {
                if (client.address == address) {
                    count++;
                    break;
                }
            }
        }
        return count;
    }

    internal void sync(List<weak Client> clients) {
        var previous_workspace = workspace;
        if (!same_clients(clients)) {
            _clients = clients.copy();
            notify_property("clients");
        }

        Client? representative = null;
        Client? visible = null;
        foreach (var client in _clients) {
            if (representative == null) representative = client;
            if (client.visible) {
                visible = client;
                break;
            }
        }

        visible_client = visible;
        var state = visible ?? representative;
        if (state == null) {
            workspace = null;
            monitor = null;
            return;
        }

        mapped = state.mapped;
        hidden = state.hidden;
        floating = state.floating;
        pinned = state.pinned;
        x = state.x;
        y = state.y;
        width = state.width;
        height = state.height;
        workspace = state.workspace;
        monitor = state.monitor;

        if ((previous_workspace != null) && (workspace != previous_workspace)) {
            moved_to(workspace);
        }
    }

    public void focus() {
        var client = visible_client ?? _clients.nth_data(0);
        if (client != null) client.focus();
    }

    public void toggle_floating() {
        var client = visible_client ?? _clients.nth_data(0);
        if (client != null) client.toggle_floating();
    }
}
}
