import { Config } from "effect";

/**
 * Connection config sourced from the environment via Effect `Config`.
 *
 *   ROKU_HOST  (default 192.168.1.240)
 *   ROKU_PORT  (default 8085 — the BrightScript debug console; SceneGraph is 8087)
 */
export const RokuConfig = Config.all({
  host: Config.string("ROKU_HOST").pipe(Config.withDefault("192.168.1.240")),
  port: Config.integer("ROKU_PORT").pipe(Config.withDefault(8085)),
});

export type RokuConfig = {
  readonly host: string;
  readonly port: number;
};
