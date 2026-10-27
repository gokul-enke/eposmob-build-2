# features/ai_assistant

The in-app AI assistant: a panel that floats above every page, opened from the
first sidebar item. It answers questions about the signed-in store's sales,
products, stock and customers (with charts and tables), explains the page the
user has open, and answers how-to questions from the CloudPOS docs.

The AI itself runs on Cloudflare: `ai.cloudposai.com`, code in the
`cloudpos-docs` repo under `workers/ai`. This feature is only the client.

```text
features/ai_assistant/
├── domain/ai_models.dart            events, charts/tables, messages, page info
├── data/
│   ├── ai_assistant_api.dart        HTTP: login exchange, chat stream, history
│   └── ai_sse_parser.dart           text/event-stream → AiChatEvent
└── presentation/
    ├── state/
    │   ├── ai_assistant_controller.dart  app-wide panel + chat state (one instance)
    │   └── ai_page_context.dart          which screen is open (+ AiPageContextScope)
    └── widgets/
        ├── ai_assistant_overlay.dart     panel / minimised bubble (in main.dart's builder)
        ├── ai_message_view.dart          bubbles, progress steps, markdown answer
        └── ai_visual_view.dart           fl_chart charts and tables
```

## How it fits in

- `main.dart` stacks `AiAssistantOverlay` over every page and adds
  `AiPageContext.instance.observer` to the navigator observers.
- The sidebar (`side_menu.dart`, `side_menu_mobile.dart`) opens it with
  `AiAssistantController.instance.open()`.
- `SessionResetService` calls `AiAssistantController.instance.reset()` on logout.
- **No second sign-in.** The API exchanges the POS login (`api_key` +
  `access_token` + `active_store_id` from SharedPreferences) for an AI session
  via `POST /api/session/exchange`. The backend verifies the token against the
  tenant's own API, and the AI can only read what that user can read.
- **Page context.** Each question carries the current screen: a page's
  `AiPageContextScope` details if it has one, otherwise the top route name, otherwise
  the sidebar screen. Users can switch it off with the "Using this page" chip.
  To make a page explainable, wrap it:

  ```dart
  AiPageContextScope(
    screen: 'Sales order details',
    details: 'Order 2-11-261027-0002; status CONFIRMED; net payable 200',
    child: page,
  )
  ```

  Keep details short and factual, and never include secrets such as tokens or
  card numbers.
- Closing or minimising keeps the conversation; a reply still streams while
  minimised, and the bubble shows a dot. Chats are saved server-side for
  180 days and appear under "Your chats".
- Abuse and cost limits are enforced server-side: 30 messages a minute and
  500 a day per user. Errors from the backend are shown on the answer.
