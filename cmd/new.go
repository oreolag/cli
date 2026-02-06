package cmd

import (
	newcmd "oreolag/cli/cmd/new"

	"github.com/spf13/cobra"
)

var newCmd = &cobra.Command{
	Use:   "new",
	Short: "Create new project",
}

func init() {
	rootCmd.AddCommand(newCmd)

	// Attach: odev new nccl
	newCmd.AddCommand(newcmd.NcclCmd)
}