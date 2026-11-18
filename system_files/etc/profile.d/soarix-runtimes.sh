# Programs installed with soarix-runtime (node, java, php, ...) live here.
case ":$PATH:" in
  *":$HOME/.local/share/soarix/bin:"*) ;;
  *) PATH="$HOME/.local/share/soarix/bin:$PATH" ;;
esac
export PATH
