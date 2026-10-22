# LandLedger
1. Deploy `contract/LandLedger.sol` on BOT Chain. The deployer becomes the registrar (admin).
2. Set `CONTRACT_ADDRESS` in `js/app.js`.
3. Serve the folder (e.g. VS Code Live Server) and open `index.html`.
Flow: registrar registers a property -> owner lists it -> buyer pays into escrow -> owner confirms (paid, minus 1% registry fee, title moves) or rejects (buyer refunded). Buyers can cancel before confirmation.
Not audited; test on a testnet first. Legal land transfer rules in your jurisdiction still apply.
# TraceChain
