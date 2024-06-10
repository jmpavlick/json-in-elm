import { Elm } from './example/src/Main.elm'

Elm.Main.init({
  node: document.getElementById('elm-node'),
  flags: "Initial Message"
})