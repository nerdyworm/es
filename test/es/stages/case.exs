defmodule ES.Stages.Case do
  use ExUnit.CaseTemplate

  using do
    quote location: :keep do
      test "will deliver events", %{stage: stage} do
        assert :ok = stage.notify(%ES.Event{event_id: 1})
        assert_receive {:bloated, {:enriched, %ES.Event{event_id: 1}}}

        assert :ok = stage.notify(%ES.Event{event_id: 2})
        assert_receive {:bloated, {:enriched, %ES.Event{event_id: 2}}}
      end
    end
  end
end
