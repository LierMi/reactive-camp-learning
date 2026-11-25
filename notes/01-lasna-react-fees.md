# 读懂费用：用 cast 查询 Lasna 系统合约参数

- 查询日期：2026-11-25（UTC）
- 网络：Reactive Lasna（Chain ID `5318007`）
- RPC：`https://lasna-rpc.rnk.dev/`
- 系统合约：`0x8888888888888888888888888888888888888888`

## 三条 cast 命令及输出

```bash
$ cast call 0x8888888888888888888888888888888888888888 '_gasPriceCoeffPer1000()' --rpc-url https://lasna-rpc.rnk.dev/ | cast to-dec
1000

$ cast call 0x8888888888888888888888888888888888888888 '_extraGas()' --rpc-url https://lasna-rpc.rnk.dev/ | cast to-dec
100000

$ cast call 0x8888888888888888888888888888888888888888 '_maxChargeGas()' --rpc-url https://lasna-rpc.rnk.dev/ | cast to-dec
50000
```

## 1. 一次 `react()` 的费用怎么算？

费用 = 基础 gas 价格 ×（`_gasPriceCoeffPer1000 / 1000`）×（实际消耗 gas + `_extraGas`）。基础 gas 价格取 `tx.gasprice` 和 `block.basefee` 中较大的值。本次读到系数为 `1000 / 1000 = 1`，固定附加 gas 为 `100000`，因此按查询时的参数，费用 = 基础 gas 价格 ×（实际消耗 gas + `100000`）。

`_maxChargeGas = 50000` 是结算付款时调用 `pay()` 的 gas 上限，不计入费用公式。这些参数以后可能调整，需要重新查询。

## 2. `balance`、`reserves`、`debt` 是什么？为什么一点 debt 也会停？

- `balance`：Reactive 合约自己持有的资金。
- `reserves`：预存在系统合约里、用于支付该合约费用的资金。
- `debt`：系统合约记录的未付费用。

结算时先使用 `reserves`；不足时尝试从合约的 `balance` 收取，仍未付清的金额留在 `debt`。系统合约在调用 `react()` 前先检查 `debt`，只要大于零就停止调用；它没有“欠得少仍可继续执行”的阈值。

## 3. `react()` 回滚了，还收费吗？对设计有什么影响？

还收费。系统合约会捕获 `react()` 的回滚、记录失败，然后仍按已消耗的 gas 计费。因此我会用准确的订阅条件减少无关事件；在 `react()` 中遇到不需要处理的事件时尽早 `return`，不用 `revert` 作为过滤方式，并测试可能失败的路径，避免反复失败耗尽资金。

## 参考

- [Reactive 官方费用与系统交互说明](https://dev.reactive.network/economy)
- [Reactive 官方调试说明](https://dev.reactive.network/debugging)
