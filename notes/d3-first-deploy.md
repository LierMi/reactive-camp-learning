# 第一次部署：监控 Sepolia 上的代币转账

- Lasna 监控合约：[Reactscan 合约页面](https://lasna.reactscan.net/address/0x0fAc4f109BF70F52EaadF42A4715599FA2b318b5)
- `react()` 调用：[Reactscan 交易页面](https://lasna.reactscan.net/tx/0x77127196b69f30f64b96c25565ba9d637b7662f47a2ca7b98e3fb3d5966e83c2)
- 订阅过滤条件：监听 Sepolia 测试 USDC 合约的所有 `Transfer` 事件，不限制转出或转入地址，处理 3 次后自动退订。
