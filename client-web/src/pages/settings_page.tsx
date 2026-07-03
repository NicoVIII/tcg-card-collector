import { Show, createEffect, createSignal } from "solid-js";
import { useRefreshCatalogMutation } from "../data/card_catalog/mutation";
import { mapError } from "../data/http/error";
import { useUpdateSettingsMutation } from "../data/settings/mutation";
import { useSettingsQuery } from "../data/settings/query";

export function SettingsPage() {
  const settingsQuery = useSettingsQuery();
  const updateMutation = useUpdateSettingsMutation();
  const refreshMutation = useRefreshCatalogMutation();

  const [defaultSort, setDefaultSort] = createSignal("card_name");
  const [defaultGrouping, setDefaultGrouping] = createSignal("location_name");
  const [saveError, setSaveError] = createSignal<string | null>(null);
  const [saved, setSaved] = createSignal(false);

  let initializedFromServer = false;
  createEffect(() => {
    const data = settingsQuery.data;
    if (data !== undefined && !initializedFromServer) {
      initializedFromServer = true;
      setDefaultSort(data.default_sort);
      setDefaultGrouping(data.default_grouping);
    }
  });

  const saveSettings = async () => {
    setSaveError(null);
    setSaved(false);
    try {
      await updateMutation.mutateAsync({
        default_sort: defaultSort(),
        default_grouping: defaultGrouping(),
      });
      setSaved(true);
    } catch (error) {
      setSaveError(mapError(error).message);
    }
  };

  return (
    <section>
      <h2>Settings</h2>
      <button onClick={() => refreshMutation.mutate()} disabled={refreshMutation.isPending}>
        Manual catalog refresh
      </button>
      <Show when={settingsQuery.isLoading}>
        <p>Loading settings...</p>
      </Show>
      <Show when={settingsQuery.isError}>
        <p role="alert">{mapError(settingsQuery.error).message}</p>
      </Show>
      <Show when={!settingsQuery.isLoading}>
        <div>
          <label>
            Default sort
            <input
              value={defaultSort()}
              onInput={(event) => {
                setDefaultSort(event.currentTarget.value);
                setSaved(false);
              }}
            />
          </label>
          <label>
            Default grouping
            <input
              value={defaultGrouping()}
              onInput={(event) => {
                setDefaultGrouping(event.currentTarget.value);
                setSaved(false);
              }}
            />
          </label>
        </div>
        <button onClick={saveSettings} disabled={updateMutation.isPending}>
          Save settings
        </button>
        <Show when={saveError() !== null}>
          <p role="alert">{saveError()}</p>
        </Show>
        <Show when={saved()}>
          <p>Settings saved.</p>
        </Show>
      </Show>
    </section>
  );
}
