import { createSignal } from "solid-js";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { useUpdateSettingsMutation } from "../data/settings/mutation";
import { useSettingsQuery } from "../data/settings/query";

export function SettingsPage() {
  const settingsQuery = useSettingsQuery();
  const updateMutation = useUpdateSettingsMutation();
  const refreshMutation = useRefreshCatalogMutation();

  const [defaultSort, setDefaultSort] = createSignal("card_name");
  const [defaultGrouping, setDefaultGrouping] = createSignal("location");

  const saveSettings = async () => {
    await updateMutation.mutateAsync({
      default_sort: defaultSort(),
      default_grouping: defaultGrouping(),
    });
  };

  return (
    <section>
      <h2>Settings</h2>
      <button onClick={() => refreshMutation.mutate()} disabled={refreshMutation.isPending}>
        Manual catalog refresh
      </button>
      <div>
        <input
          value={defaultSort()}
          onInput={(event) => setDefaultSort(event.currentTarget.value)}
        />
        <input
          value={defaultGrouping()}
          onInput={(event) => setDefaultGrouping(event.currentTarget.value)}
        />
      </div>
      <button onClick={saveSettings} disabled={updateMutation.isPending}>
        Save settings
      </button>
      <pre>{JSON.stringify(settingsQuery.data, null, 2)}</pre>
    </section>
  );
}
