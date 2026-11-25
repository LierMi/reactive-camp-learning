# 读懂费用：用 cast 查询 Lasna 系统合约参数

- 查询日期：2026-11-25（UTC）
- 网络：Reactive Lasna 测试网（Chain ID `5318007`）
- RPC：`https://lasna-rpc.rnk.dev/`
- 系统合约：`0x8888888888888888888888888888888888888888`

## 我是怎么做的

`cast` 是 Foundry 的命令行工具。这里用 `cast call` 读取合约状态，属于只读查询，不用钱包、私钥或测试币。命令末尾的 `cast to-dec` 把合约返回的十六进制数转成十进制，方便看数值。

在终端依次运行以下三条命令，我得到：

```bash
$ cast call 0x8888888888888888888888888888888888888888 '_gasPriceCoeffPer1000()' --rpc-url https://lasna-rpc.rnk.dev/ | cast to-dec
1000

$ cast call 0x8888888888888888888888888888888888888888 '_extraGas()' --rpc-url https://lasna-rpc.rnk.dev/ | cast to-dec
100000

$ cast call 0x8888888888888888888888888888888888888888 '_maxChargeGas()' --rpc-url https://lasna-rpc.rnk.dev/ | cast to-dec
50000
```

这三个参数可由系统合约所有者调整，因此上面是查询当时的值，以后使用时应重新读取。

## 1. 一次 `react()` 的费用怎么算？

我理解为：先取基础 gas 价格，再乘价格系数，最后乘“这次执行实际用掉的 gas + 固定附加 gas”。公式是：

```text
费用 = 基础 gas 价格 × (_gasPriceCoeffPer1000 / 1000) × (实际消耗 gas + _extraGas)
```

基础 gas 价格取 `tx.gasprice` 与 `block.basefee` 中较大的那个。今天查到的系数 `1000 / 1000 = 1`，固定附加 gas 是 `100000`。因此按当前参数，公式可以写成 `费用 = 基础 gas 价格 × (实际消耗 gas + 100000)`。

例如，**仅作算例**：若实际消耗 `50000 gas`，基础 gas 价格为 `100 gwei`，费用就是 `100 gwei × (50000 + 100000) = 0.015 REACT`。这里的 gas 价格和实际用量是举例，不是这次查询得到的实时值。

`_maxChargeGas = 50000` **不加进这个公式**。它是系统合约在需要调用付款逻辑 `pay()` 时，给这一步设置的 gas 上限，也不是 `react()` 的执行 gas 上限。

## 2. `balance`、`reserves`、`debt` 是什么？为什么一点 debt 也会停？

| 名称 | 我理解的意思 |
| --- | --- |
| `balance` | Reactive 合约自身持有的 REACT，可以用来付款。 |
| `reserves` | 存在系统合约里、专门为这个 Reactive 合约预付费用的资金。收费时先扣它。 |
| `debt` | 系统合约记录的未付费用。 |

系统合约在调用 `react()` **之前**先检查 `debt`。只要 `debt > 0`，它就不会继续调用这个合约的 `react()`；规则没有“欠得少就通融”的阈值。这避免继续为尚未结清费用的合约提供执行服务。

直接给合约转 REACT 只会增加它的 `balance`，不会自动清除已经存在的 `debt`。要恢复执行，可以向系统合约调用 `depositTo(合约地址)`，它会先还债，再把剩余资金记入 `reserves`；如果合约自己公开了 `coverDebt()`，也可以用合约余额主动还债。

## 3. `react()` 回滚了，还收费吗？对设计有什么影响？

**还收费。** 系统合约会捕获 `react()` 的回滚、记录失败事件，然后仍按已经消耗的 gas 计费。一次失败的执行也占用了网络计算资源，所以不能把 `revert` 当作免费的事件过滤器。

写合约时，我会尽量把订阅条件设准；在 `react()` 里遇到无需处理的事件，做判断后尽早 `return`，而不是 `revert`。还要在本地测试可能失败的路径，并留意资金和 `debt`：如果错误反复触发，失败费用会持续消耗资金，最终让合约停止响应。

## 资料

- [Reactive 官方：Economy & System Interactions](https://dev.reactive.network/economy)
- [Reactive 官方：Debugging](https://dev.reactive.network/debugging)
- [学习营 starter 仓库](https://github.com/ethpanda-org/reactive-builder-camp/tree/main/starter)
