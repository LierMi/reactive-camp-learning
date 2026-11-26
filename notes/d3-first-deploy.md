# 第一次部署：监控 Sepolia 上的代币转账

## 部署与订阅

- Lasna 监控合约：[Reactscan 合约页面](https://lasna.reactscan.net/address/0x0fAc4f109BF70F52EaadF42A4715599FA2b318b5)
- 源链：Sepolia（链 ID `11155111`）；代币：测试 USDC `0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238`。
- 订阅过滤条件：只接收该代币的 `Transfer` 事件；发送方、接收方等其余 topic 使用 `REACTIVE_IGNORE`，因此任何地址之间的转账都可以触发。
- 部署时存入 `0.2 lREACT`，设置 `maxEvents_ = 3`；`react()` 仅允许系统调用，处理第 3 次后自动取消订阅。

## 触发记录

**提交用 `react()` 交易链接：** https://lasna.reactscan.net/tx/0x77127196b69f30f64b96c25565ba9d637b7662f47a2ca7b98e3fb3d5966e83c2

| 次数 | Sepolia 转账交易 | Lasna `react()` 交易 |
| --- | --- | --- |
| 1 | [源交易](https://sepolia.etherscan.io/tx/0xea175ca78914fc502bb72a50090f04ea5bf6753be83fd7394c3e2b22e36110ca) | [调用交易](https://lasna.reactscan.net/tx/0x77127196b69f30f64b96c25565ba9d637b7662f47a2ca7b98e3fb3d5966e83c2) |
| 2 | [源交易](https://sepolia.etherscan.io/tx/0xfa961c13386bbf17eaa817b79eb493cdf389e78bebf3dd8e672dffc8b5861542) | [调用交易](https://lasna.reactscan.net/tx/0x0562b6868ff6c85289dec0aa8595de70b9f77899978c1dfef91524f8173948dd) |
| 3 | [源交易](https://sepolia.etherscan.io/tx/0x91bba7f12e77dd42972a019bbb2835171d66bfeebc29777456531705d0cfd698) | [调用交易](https://lasna.reactscan.net/tx/0x6825b63d780d60153260505064e24c1ff45582b0f41184fcb336acae4c5465a7) |

链上最终状态：`seen = 3`、`remaining = 0`、`debt = 0`。
